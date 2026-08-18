"""Shared bits for the ingest: db handle, matching keys, title resolution.

Every source goes through `resolve_title` so cross-source matching happens in
exactly one place and records how it matched.
"""

from __future__ import annotations

import hashlib
import json
import re
import sqlite3
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_DB = ROOT / "data" / "record.db"

_PUNCT = re.compile(r"[^\w\s]", re.UNICODE)
_SPACE = re.compile(r"\s+", re.UNICODE)


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def pushbr_url(name: str | None) -> str | None:
    """kino.pub-adjacent actor portrait, keyed by MD5 of the (Russian) name —
    the scheme kpapp.link itself uses: m.pushbr.com/actors/<md5(name)>.jpg.

    Free: no fetch, no quota, no matching problem — the URL is a pure function
    of a name we already hold. A miss (no such photo) is a 403 at *display*
    time, same as any other candidate in an ordered fallback list. This mirrors
    KinoPubAppleClient/Services/ActorImages/ActorImageProvider.swift; the server
    computing it too is what lets the API's own document carry it, instead of
    every client re-deriving the same hash.
    """
    trimmed = (name or "").strip()
    if not trimmed:
        return None
    digest = hashlib.md5(trimmed.encode("utf-8")).hexdigest()
    return f"https://m.pushbr.com/actors/{digest}.jpg"


def match_key(value: str | None) -> str | None:
    """Normalized form used for title/person matching.

    Casefold, strip diacritics, drop punctuation, collapse whitespace. This is a
    *matching* key, never a display value, and never a cross-alphabet bridge —
    Cyrillic and Latin normalize to different strings by design. Pairing those
    is the id-join job, not this function's.
    """
    if not value:
        return None
    text = unicodedata.normalize("NFKD", value)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = _PUNCT.sub(" ", text.casefold())
    text = _SPACE.sub(" ", text).strip()
    return text or None


# Tables rebuilt from `raw_payload` by a re-derive. `raw_payload`, `fetch_log`,
# `provider_health` and `ingest_run` are deliberately absent: they are the layer
# that cost quota to obtain, and nothing that changes the schema may drop them.
DERIVED_TABLES = (
    "title_credit", "person_external_id", "person", "image", "rating", "trailer",
    "badge", "season", "episode", "award", "genre", "country", "synopsis",
    "fact", "review",
    "copy_segment", "copy_video", "title_copy", "title_external_id", "title",
)

# Additive column changes, applied in place. Anything that cannot be an ALTER
# (dropping a primary key, say) belongs in `MIGRATIONS` as explicit SQL.
EXPECTED_COLUMNS = {
    "rating": {"first_seen_at": "TEXT", "changed_at": "TEXT"},
    "episode": {"runtime": "INTEGER", "still": "TEXT"},
    # Provenance for the one stored photo, so the document builder can decide
    # per title whether to trust it ahead of the free pushbr candidate — a
    # bare URL with no source is a precedence decision already made and lost.
    "person": {"photo_source": "TEXT"},
}

MIGRATIONS: list[tuple[int, str]] = [
    # (version, sql). Append only; never edit a shipped step.
]


def migrate(conn) -> list[str]:
    """Bring an existing record up to the current schema without dropping it.

    Returns what it did, so a caller can say so rather than silently mutating a
    database the user has spent quota filling.
    """
    applied: list[str] = []
    conn.execute("CREATE TABLE IF NOT EXISTS schema_version("
                 "version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)")
    current = conn.execute("SELECT COALESCE(max(version), 0) FROM schema_version").fetchone()[0]

    for table, columns in EXPECTED_COLUMNS.items():
        existing = {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}
        if not existing:
            continue
        for column, declaration in columns.items():
            if column not in existing:
                conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")
                applied.append(f"{table}.{column}")

    for version, sql in MIGRATIONS:
        if version > current:
            conn.executescript(sql)
            conn.execute("INSERT INTO schema_version(version, applied_at) VALUES (?,?)",
                         (version, now()))
            applied.append(f"migration {version}")

    conn.commit()
    return applied


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.executescript((ROOT / "schema.sql").read_text())
    migrate(conn)
    return conn


def wipe_derived(conn) -> None:
    """Drop only what can be rebuilt. Raw payloads and fetch_log survive."""
    conn.execute("PRAGMA foreign_keys = OFF")
    for table in DERIVED_TABLES:
        conn.execute(f"DELETE FROM {table}")
    for table in ("title", "person", "title_copy"):
        conn.execute("DELETE FROM sqlite_sequence WHERE name=?", (table,))
    conn.execute("PRAGMA foreign_keys = ON")
    conn.commit()


def fetched_raw_count(conn) -> int:
    """How many rows in the record were paid for with somebody's quota."""
    return conn.execute(
        "SELECT count(*) FROM raw_payload WHERE via='fetch'").fetchone()[0]


def store_raw(conn, source, kind, source_key, body, via="dump") -> None:
    conn.execute(
        "INSERT OR REPLACE INTO raw_payload(source,kind,source_key,via,body,fetched_at)"
        " VALUES (?,?,?,?,?,?)",
        (source, kind, str(source_key), via,
         body if isinstance(body, str) else json.dumps(body, ensure_ascii=False), now()),
    )


def find_by_external(conn, namespace, value) -> int | None:
    if value in (None, "", 0):
        return None
    row = conn.execute(
        "SELECT title_id FROM title_external_id WHERE namespace=? AND value=?",
        (namespace, str(value)),
    ).fetchone()
    return row["title_id"] if row else None


def link_external(conn, title_id, namespace, value, method, confidence=1.0) -> None:
    if value in (None, "", 0):
        return
    conn.execute(
        "INSERT OR IGNORE INTO title_external_id(title_id,namespace,value,confidence,method)"
        " VALUES (?,?,?,?,?)",
        (title_id, namespace, str(value), confidence, method),
    )


def resolve_title(conn, *, ids: dict, kind=None, title_ru=None,
                  title_original=None, year=None, allow_title_match=True):
    """Find or create a title. Returns (title_id, method).

    Ladder, strongest first:
      1. any external id we already hold
      2. normalized original title + year (±1, since sources disagree on the
         release year of the same film by a year all the time)
      3. normalized Russian title + year
      4. create a new title
    """
    for namespace, value in ids.items():
        found = find_by_external(conn, namespace, value)
        if found:
            return found, f"id:{namespace}"

    norm_orig = match_key(title_original)
    norm_ru = match_key(title_ru)

    if allow_title_match and year:
        for column, needle in (("norm_original", norm_orig), ("norm_ru", norm_ru)):
            if not needle:
                continue
            row = conn.execute(
                f"SELECT id FROM title WHERE {column}=? AND year BETWEEN ? AND ? LIMIT 2",
                (needle, year - 1, year + 1),
            ).fetchall()
            # Ambiguous match is not a match. Two films with the same original
            # title in the same year exist, and guessing is worse than a new row.
            if len(row) == 1:
                return row[0]["id"], f"title_year:{column}"

    stamp = now()
    cursor = conn.execute(
        "INSERT INTO title(kind,title_ru,title_original,year,norm_original,norm_ru,"
        "created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)",
        (kind, title_ru, title_original, year, norm_orig, norm_ru, stamp, stamp),
    )
    return cursor.lastrowid, "new"


def enrich_title(conn, title_id, *, kind=None, title_ru=None,
                 title_original=None, year=None) -> None:
    """Fill gaps on an existing title. Never overwrites a value we already have."""
    row = conn.execute("SELECT * FROM title WHERE id=?", (title_id,)).fetchone()
    updates, params = [], []
    for column, value in (("kind", kind), ("title_ru", title_ru),
                          ("title_original", title_original), ("year", year)):
        if value and not row[column]:
            updates.append(f"{column}=?")
            params.append(value)
    if title_ru and not row["norm_ru"]:
        updates.append("norm_ru=?")
        params.append(match_key(title_ru))
    if title_original and not row["norm_original"]:
        updates.append("norm_original=?")
        params.append(match_key(title_original))
    if not updates:
        return
    updates.append("updated_at=?")
    params.extend([now(), title_id])
    conn.execute(f"UPDATE title SET {', '.join(updates)} WHERE id=?", params)


def resolve_person(conn, *, name_ru=None, name_en=None, ids: dict | None = None):
    """Find or create a person. Ids win; names match within one alphabet only."""
    norm_ru, norm_en = match_key(name_ru), match_key(name_en)

    for namespace, value in (ids or {}).items():
        if value in (None, "", 0):
            continue
        row = conn.execute(
            "SELECT person_id FROM person_external_id WHERE namespace=? AND value=?",
            (namespace, str(value)),
        ).fetchone()
        if row:
            # Fill whichever spelling this caller brought. Finding the person by
            # id and then dropping their Russian name defeats the entire
            # id-join strategy: two passes in two languages are *supposed* to
            # meet here and leave a pair behind.
            if name_ru or name_en:
                conn.execute(
                    "UPDATE person SET name_ru=COALESCE(name_ru,?), name_en=COALESCE(name_en,?),"
                    " norm_ru=COALESCE(norm_ru,?), norm_en=COALESCE(norm_en,?) WHERE id=?",
                    (name_ru, name_en, norm_ru, norm_en, row["person_id"]),
                )
            return row["person_id"]
    for column, needle in (("norm_en", norm_en), ("norm_ru", norm_ru)):
        if not needle:
            continue
        row = conn.execute(
            f"SELECT id FROM person WHERE {column}=? LIMIT 1", (needle,)
        ).fetchone()
        if row:
            if name_ru or name_en:
                conn.execute(
                    "UPDATE person SET name_ru=COALESCE(name_ru,?), name_en=COALESCE(name_en,?),"
                    " norm_ru=COALESCE(norm_ru,?), norm_en=COALESCE(norm_en,?) WHERE id=?",
                    (name_ru, name_en, norm_ru, norm_en, row["id"]),
                )
            return row["id"]

    cursor = conn.execute(
        "INSERT INTO person(name_ru,name_en,norm_ru,norm_en) VALUES (?,?,?,?)",
        (name_ru, name_en, norm_ru, norm_en),
    )
    person_id = cursor.lastrowid
    for namespace, value in (ids or {}).items():
        if value not in (None, "", 0):
            conn.execute(
                "INSERT OR IGNORE INTO person_external_id(person_id,namespace,value)"
                " VALUES (?,?,?)", (person_id, namespace, str(value)),
            )
    return person_id


def add_rating(conn, title_id, source, value, votes, *, season=None, episode=None, scale=10.0):
    """Write a rating, but never let a staler number win.

    Vote counts only ever grow, which makes them a free monotonic clock: a
    payload reporting *fewer* votes than we hold is older than what we have,
    whatever its own timestamp claims. Blind INSERT OR REPLACE would let a
    cached CDN response quietly walk a rating backwards.
    """
    if value in (None, "", 0) and votes in (None, 0):
        return
    stamp = now()
    existing = conn.execute(
        "SELECT value, votes, first_seen_at, changed_at FROM rating"
        " WHERE title_id=? AND source=? AND COALESCE(season,-1)=? AND COALESCE(episode,-1)=?",
        (title_id, source, -1 if season is None else season,
         -1 if episode is None else episode),
    ).fetchone()

    if existing is None:
        conn.execute(
            "INSERT INTO rating(title_id,source,season,episode,value,votes,scale,fetched_at,"
            "first_seen_at,changed_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (title_id, source, season, episode, value, votes, scale, stamp, stamp, stamp),
        )
        return

    if (votes is not None and existing["votes"] is not None and votes < existing["votes"]):
        # Older than what we hold. Record that we looked, keep the better number.
        conn.execute(
            "UPDATE rating SET fetched_at=? WHERE title_id=? AND source=?"
            " AND COALESCE(season,-1)=? AND COALESCE(episode,-1)=?",
            (stamp, title_id, source, -1 if season is None else season,
             -1 if episode is None else episode),
        )
        return

    moved = (value != existing["value"]) or (votes != existing["votes"])
    conn.execute(
        "UPDATE rating SET value=COALESCE(?,value), votes=COALESCE(?,votes), scale=?,"
        " fetched_at=?, first_seen_at=COALESCE(first_seen_at,?), changed_at=?"
        " WHERE title_id=? AND source=? AND COALESCE(season,-1)=? AND COALESCE(episode,-1)=?",
        (value, votes, scale, stamp, stamp,
         stamp if moved else (existing["changed_at"] or stamp),
         title_id, source, -1 if season is None else season,
         -1 if episode is None else episode),
    )


def add_image(conn, title_id, kind, source, url, *, stable=True, lang=None):
    if not url:
        return
    conn.execute(
        "INSERT OR IGNORE INTO image(title_id,kind,source,url,stable,lang)"
        " VALUES (?,?,?,?,?,?)", (title_id, kind, source, url, 1 if stable else 0, lang),
    )


def upsert_copy(conn, title_id, platform, platform_key, *, url=None, seasons=None) -> int:
    """One platform's copy of a title. Streams, tracks and encode markers hang here."""
    row = conn.execute(
        "SELECT id FROM title_copy WHERE platform=? AND platform_key=?",
        (platform, str(platform_key)),
    ).fetchone()
    if row:
        conn.execute("UPDATE title_copy SET url=COALESCE(?,url), seasons=COALESCE(?,seasons),"
                     " updated_at=? WHERE id=?", (url, seasons, now(), row["id"]))
        return row["id"]
    cursor = conn.execute(
        "INSERT INTO title_copy(title_id,platform,platform_key,url,seasons,updated_at)"
        " VALUES (?,?,?,?,?,?)", (title_id, platform, str(platform_key), url, seasons, now()),
    )
    return cursor.lastrowid


def add_rows(conn, table, columns, rows):
    if not rows:
        return
    placeholders = ",".join("?" * len(columns))
    conn.executemany(
        f"INSERT OR IGNORE INTO {table}({','.join(columns)}) VALUES ({placeholders})", rows
    )


class Run:
    """One source's ingest, logged to `ingest_run` whether it succeeds or not."""

    def __init__(self, conn, source):
        self.conn, self.source = conn, source
        self.raw = self.new = self.seen = 0
        cursor = conn.execute(
            "INSERT INTO ingest_run(source,started_at) VALUES (?,?)", (source, now())
        )
        self.id = cursor.lastrowid

    def finish(self, note=None):
        self.conn.execute(
            "UPDATE ingest_run SET finished_at=?, raw_rows=?, titles_new=?, titles_seen=?, note=?"
            " WHERE id=?",
            (now(), self.raw, self.new, self.seen, note, self.id),
        )
        self.conn.commit()

    def count(self, method):
        if method == "new":
            self.new += 1
        else:
            self.seen += 1
