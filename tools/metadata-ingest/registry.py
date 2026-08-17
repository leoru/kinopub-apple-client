"""Provider registry: descriptors, pacing, and per-provider failure isolation.

Ported in design (not in code) from `Plozz/Sources/MetadataKit` — `RateLimiter`
and `ProviderCircuitBreaker`. Two ideas were worth taking:

**Token bucket, not a reservation cursor.** Our first pacer handed out
monotonically increasing time slots and advanced a cursor on every call. Plozz
abandoned that same design because an abandoned reservation never rolls back and
poisons the schedule for everyone behind it. A bucket only spends a token when
one is actually there, so an aborted call costs nothing.

**Failure kind decides the cooldown.** A timeout, a 401 and a 429 are three
different conditions and deserve three different waits. This is exactly what bit
us on OMDb: an invalid key looked like "no such title" and got written into
`fetch_log` as a permanent negative. A breaker that opens on auth for a long
cooldown makes that structurally impossible rather than merely handled.

One deliberate divergence: their breaker lives in memory inside one long-running
app. Our runs are separate short processes, so health is **persisted** — a key
that was invalid two minutes ago must still be invalid when the next `make`
starts, or the isolation is theatre.
"""

from __future__ import annotations

import sqlite3
import threading
import time
from dataclasses import dataclass, field

from common import now

SCHEMA = """
CREATE TABLE IF NOT EXISTS provider_health (
  provider     TEXT PRIMARY KEY,
  open_until   TEXT,
  open_reason  TEXT,
  consecutive  INTEGER NOT NULL DEFAULT 0,
  last_error   TEXT,
  last_ok_at   TEXT,
  calls_ok     INTEGER NOT NULL DEFAULT 0,
  calls_failed INTEGER NOT NULL DEFAULT 0,
  spent_today  INTEGER NOT NULL DEFAULT 0,
  spent_day    TEXT
);
"""


# --------------------------------------------------------------- descriptors

@dataclass(frozen=True)
class ProviderSpec:
    """What a provider can do, declared once, so callers stop hardcoding it.

    The registry answers "who can fill this gap, and may I call them right now"
    — which is what makes adding provider #7 a data change instead of a code
    change.
    """
    name: str
    auth: str                      # none | system_key | user_key | oauth
    accepts: tuple = ()            # id namespaces it can be queried by
    supplies: tuple = ()           # field groups it can fill
    daily_quota: int | None = None
    rps: float = 5.0
    burst: int = 5
    notes: str = ""


PROVIDERS = {
    "tmdb": ProviderSpec(
        name="tmdb", auth="system_key",
        accepts=("imdb", "tmdb", "tvdb"),
        supplies=("identity", "credits", "images", "videos", "keywords",
                  "ratings", "watch_providers", "episodes"),
        daily_quota=None, rps=12.0, burst=12,
        notes="No documented hard limit; throttles abuse. Proxied via our worker.",
    ),
    "omdb": ProviderSpec(
        name="omdb", auth="system_key",
        accepts=("imdb",),
        supplies=("ratings",),
        daily_quota=1000, rps=3.0, burst=3,
        notes="RT + Metacritic, movies only. Errors arrive as HTTP 200.",
    ),
    "kinopoisk": ProviderSpec(
        name="kinopoisk", auth="user_key",
        accepts=("kinopoisk",),
        supplies=("awards", "facts", "stills", "ru_names", "episodes"),
        daily_quota=500, rps=1.0, burst=2,
        notes="User's own key — never our quota.",
    ),
}


# ------------------------------------------------------------- token bucket

class TokenBucket:
    """Starts full at `burst`, refills at `rps`. A call that gives up costs nothing."""

    def __init__(self, rps: float, burst: int, clock=time.monotonic):
        self.refill_per_second = max(rps, 0.0001)
        self.capacity = float(max(burst, 1))
        self.tokens = self.capacity
        self.updated = clock()
        self.clock = clock
        self.lock = threading.Lock()

    def _refill(self):
        current = self.clock()
        elapsed = current - self.updated
        if elapsed > 0:
            self.tokens = min(self.capacity, self.tokens + elapsed * self.refill_per_second)
            self.updated = current

    def try_acquire(self) -> float:
        """0.0 when a token was taken, else the seconds to wait before retrying."""
        with self.lock:
            self._refill()
            if self.tokens >= 1:
                self.tokens -= 1
                return 0.0
            return (1 - self.tokens) / self.refill_per_second

    def acquire(self):
        while True:
            wait = self.try_acquire()
            if wait <= 0:
                return
            time.sleep(wait)


# ---------------------------------------------------------- circuit breaker

TRANSIENT, AUTH, RATE_LIMIT = "transient", "auth", "rate_limit"

COOLDOWN = {
    TRANSIENT: 60,        # a blip; retry soon
    AUTH: 6 * 60 * 60,    # credentials must change — do not hammer
    RATE_LIMIT: 60 * 60,  # a daily cap needs a wall clock, not a retry loop
}
FAILURE_THRESHOLD = 3     # consecutive transients before opening


@dataclass
class Health:
    open_until: float | None = None
    reason: str | None = None
    consecutive: int = 0
    probe_in_flight: bool = False
    last_error: str | None = None
    ok: int = 0
    failed: int = 0


class CircuitBreaker:
    """Per-provider. A dead source degrades its own fields and nothing else.

    Transient failures need `FAILURE_THRESHOLD` in a row to open; auth and
    rate-limit failures open immediately, because retrying them is guaranteed
    waste. After the cooldown exactly one caller is admitted as a probe, so a
    recovering source does not get a thundering herd.
    """

    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.state: dict[str, Health] = {}
        self.lock = threading.Lock()

    def _health(self, provider) -> Health:
        return self.state.setdefault(provider, Health())

    def allow(self, provider) -> bool:
        with self.lock:
            health = self._health(provider)
            if health.open_until is None:
                return True
            if self.clock() < health.open_until:
                return False
            if health.probe_in_flight:
                return False
            health.probe_in_flight = True   # admit exactly one
            return True

    def record_success(self, provider):
        with self.lock:
            health = self._health(provider)
            health.open_until = None
            health.reason = None
            health.consecutive = 0
            health.probe_in_flight = False
            health.ok += 1

    def record_failure(self, provider, kind, *, message=None, retry_after=None):
        with self.lock:
            health = self._health(provider)
            health.probe_in_flight = False
            health.failed += 1
            health.last_error = message
            if kind == TRANSIENT:
                health.consecutive += 1
                if health.consecutive < FAILURE_THRESHOLD:
                    return False
            cooldown = retry_after if retry_after is not None else COOLDOWN[kind]
            health.open_until = self.clock() + cooldown
            health.reason = kind
            return True

    def tripped(self, provider) -> bool:
        with self.lock:
            health = self._health(provider)
            return health.open_until is not None and self.clock() < health.open_until


# ------------------------------------------------------------------ runtime

@dataclass
class ProviderRuntime:
    """Spec + pacing + breaker for one provider, with health that outlives a run."""
    spec: ProviderSpec
    bucket: TokenBucket = field(init=False)
    breaker: CircuitBreaker = field(default_factory=CircuitBreaker)

    def __post_init__(self):
        self.bucket = TokenBucket(self.spec.rps, self.spec.burst)

    def acquire(self) -> bool:
        """False means the breaker is open — skip this provider, do not wait on it."""
        if not self.breaker.allow(self.spec.name):
            return False
        self.bucket.acquire()
        return True


def ensure_schema(conn):
    conn.executescript(SCHEMA)


def load_health(conn, provider) -> sqlite3.Row | None:
    return conn.execute("SELECT * FROM provider_health WHERE provider=?", (provider,)).fetchone()


def save_health(conn, provider, runtime: ProviderRuntime, *, open_seconds=None, reason=None):
    """Persist what must survive the process: an open breaker and the counters."""
    health = runtime.breaker.state.get(provider, Health())
    open_until = None
    if open_seconds:
        open_until = time.strftime("%Y-%m-%dT%H:%M:%S+00:00",
                                   time.gmtime(time.time() + open_seconds))
    conn.execute(
        "INSERT INTO provider_health(provider,open_until,open_reason,consecutive,last_error,"
        "last_ok_at,calls_ok,calls_failed) VALUES (?,?,?,?,?,?,?,?)"
        " ON CONFLICT(provider) DO UPDATE SET"
        " open_until=COALESCE(excluded.open_until, provider_health.open_until),"
        " open_reason=COALESCE(excluded.open_reason, provider_health.open_reason),"
        " consecutive=excluded.consecutive, last_error=excluded.last_error,"
        " last_ok_at=COALESCE(excluded.last_ok_at, provider_health.last_ok_at),"
        " calls_ok=provider_health.calls_ok+excluded.calls_ok,"
        " calls_failed=provider_health.calls_failed+excluded.calls_failed",
        (provider, open_until, reason or health.reason, health.consecutive,
         health.last_error, now() if health.ok else None, health.ok, health.failed),
    )


def clear_health(conn, provider):
    conn.execute("UPDATE provider_health SET open_until=NULL, open_reason=NULL,"
                 " consecutive=0 WHERE provider=?", (provider,))


def blocked_until(conn, provider) -> str | None:
    """A cooldown written by an earlier process still applies to this one."""
    row = load_health(conn, provider)
    if not row or not row["open_until"]:
        return None
    return row["open_until"] if row["open_until"] > now() else None
