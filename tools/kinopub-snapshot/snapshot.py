#!/usr/bin/env python3
"""
Snapshot of the kino.pub library (parent-level items only — movies, series, etc.,
not individual episodes) into a local SQLite file, for later offline matching
against external metadata (awards, etc.).

Auth: reads the live access/refresh token out of the macOS login keychain
(service "com.kunst.kinopub", written there by the Apple client itself),
refreshing via /oauth2/token when it expires. A local copy is cached in
data/token_cache.json so re-runs don't need Keychain access every time.

Usage:
  python3 snapshot.py                       # full sweep, all types
  python3 snapshot.py --types movie,serial  # only these types
  python3 snapshot.py --resume              # continue from last saved page per type
  python3 snapshot.py --db path/to/other.db
"""
import argparse
import json
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
import sqlite3

BASE_URL = "https://api.service-kp.com"
KEYCHAIN_SERVICE = "com.kunst.kinopub"
KEYCHAIN_ACCOUNT = "com.kunst.kinopub.token"
# Public device-auth client used by every kino.pub client (Kodi addon included) —
# the same pair already baked into KinoPubAppleClient/Info.plist. Only needed here
# to refresh an expired access token via grant_type=refresh_token.
CLIENT_ID = "xbmc"
CLIENT_SECRET = "cgg3gtifu46urtfp2zp1nqtba0k2ezxh"

ALL_TYPES = ["movie", "serial", "docuserial", "documovie", "concert", "tvshow", "3D"]
PER_PAGE = 50
REQUEST_DELAY = 0.4
MAX_RETRIES = 5

DATA_DIR = Path(__file__).parent / "data"
TOKEN_CACHE = DATA_DIR / "token_cache.json"
STATE_FILE = DATA_DIR / "progress.json"
DEFAULT_DB = DATA_DIR / "snapshot.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY,
  type TEXT NOT NULL,
  subtype TEXT,
  title TEXT NOT NULL,
  title_ru TEXT,
  title_original TEXT,
  year INTEGER,
  countries TEXT,
  imdb_id INTEGER,
  imdb_rating REAL,
  imdb_votes INTEGER,
  kinopoisk_id INTEGER,
  kinopoisk_rating REAL,
  kinopoisk_votes INTEGER,
  kinopub_rating_votes INTEGER,
  kinopub_rating_percentage REAL,
  views INTEGER,
  poster_thumb TEXT,
  poster_wide TEXT,
  finished INTEGER,
  created_at INTEGER,
  updated_at INTEGER,
  first_synced_at TEXT NOT NULL,
  last_synced_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_items_imdb ON items(imdb_id);
CREATE INDEX IF NOT EXISTS idx_items_kinopoisk ON items(kinopoisk_id);
CREATE INDEX IF NOT EXISTS idx_items_type ON items(type);
CREATE INDEX IF NOT EXISTS idx_items_created ON items(created_at);
"""


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def load_token_cache():
    if TOKEN_CACHE.exists():
        return json.loads(TOKEN_CACHE.read_text())
    return None


def save_token_cache(token):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    TOKEN_CACHE.write_text(json.dumps(token))


def token_from_keychain():
    """Best-effort only — the Keychain ACL prompt can be denied/cancelled (exit 128),
    in which case callers fall back to a manually supplied token."""
    out = subprocess.run(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE,
         "-a", KEYCHAIN_ACCOUNT, "-w"],
        capture_output=True, text=True,
    )
    if out.returncode != 0:
        return None
    return json.loads(out.stdout.strip())


def refresh_token(refresh_token_value):
    data = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "refresh_token": refresh_token_value,
    }).encode()
    req = urllib.request.Request(f"{BASE_URL}/oauth2/token", data=data, method="POST")
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read())


def get_access_token(cli_token):
    if cli_token:
        token = {"access_token": cli_token}
        save_token_cache(token)
        return token
    token = load_token_cache() or token_from_keychain()
    if not token:
        sys.exit(
            "No token available. Either:\n"
            "  - approve the macOS Keychain prompt for 'com.kunst.kinopub' and re-run, or\n"
            "  - pass one from a live app session: --token <access_token>\n"
            "    (grab it from the app's CURLLoggingPlugin console output)"
        )
    save_token_cache(token)
    return token


# Rate limit as observed live: 100 req per short (~7-10s) window via
# X-Rate-Limit-{Limit,Remaining,Reset} response headers. Our request pace stays
# well under that; this is just a safety net if it's ever tighter than observed.
RATE_LIMIT_SAFETY_MARGIN = 15


def api_get(path, params, access_token):
    qs = urllib.parse.urlencode(params)
    req = urllib.request.Request(f"{BASE_URL}{path}?{qs}",
                                  headers={"Authorization": f"Bearer {access_token}"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        body = json.loads(resp.read())
        remaining = resp.headers.get("X-Rate-Limit-Remaining")
        reset = resp.headers.get("X-Rate-Limit-Reset")
        if remaining is not None and int(remaining) < RATE_LIMIT_SAFETY_MARGIN:
            pause = int(reset) + 1 if reset else 5
            print(f"  (rate limit {remaining} left, pausing {pause}s)", flush=True)
            time.sleep(pause)
        return body


def fetch_page(path, params, token_holder):
    """token_holder: mutable dict with 'access_token'/'refresh_token', refreshed in place on 401."""
    last_err = None
    for attempt in range(MAX_RETRIES):
        try:
            return api_get(path, params, token_holder["access_token"])
        except urllib.error.HTTPError as e:
            if e.code == 401:
                if not token_holder.get("refresh_token"):
                    sys.exit("Access token expired and no refresh_token on hand — "
                             "pass a fresh one with --token.")
                refreshed = refresh_token(token_holder["refresh_token"])
                token_holder.update(refreshed)
                save_token_cache(token_holder)
                continue
            if e.code == 429 or e.code >= 500:
                last_err = e
                time.sleep(2 ** attempt)
                continue
            raise
        except (urllib.error.URLError, TimeoutError) as e:
            last_err = e
            time.sleep(2 ** attempt)
    raise RuntimeError(f"giving up on {path} {params}: {last_err}")


def split_title(raw):
    if " / " in raw:
        ru, _, orig = raw.partition(" / ")
        return ru.strip(), orig.strip()
    return raw.strip(), None


def row_from_item(item, synced_at):
    title_ru, title_original = split_title(item.get("title", ""))
    posters = item.get("posters") or {}
    countries = [c.get("title") for c in (item.get("countries") or []) if c.get("title")]
    return {
        "id": item["id"],
        "type": item.get("type"),
        "subtype": item.get("subtype") or None,
        "title": item.get("title", ""),
        "title_ru": title_ru or None,
        "title_original": title_original,
        "year": item.get("year") or None,
        "countries": json.dumps(countries, ensure_ascii=False) if countries else None,
        "imdb_id": item.get("imdb") or None,
        "imdb_rating": item.get("imdb_rating"),
        "imdb_votes": item.get("imdb_votes"),
        "kinopoisk_id": item.get("kinopoisk") or None,
        "kinopoisk_rating": item.get("kinopoisk_rating"),
        "kinopoisk_votes": item.get("kinopoisk_votes"),
        "kinopub_rating_votes": item.get("rating_votes"),
        "kinopub_rating_percentage": item.get("rating_percentage"),
        "views": item.get("views"),
        "poster_thumb": posters.get("medium"),
        "poster_wide": posters.get("wide"),
        "finished": 1 if item.get("finished") else 0,
        "created_at": item.get("created_at"),
        "updated_at": item.get("updated_at"),
        "last_synced_at": synced_at,
    }


def upsert_items(conn, items, synced_at):
    rows = [row_from_item(it, synced_at) for it in items]
    conn.executemany(
        """
        INSERT INTO items (
          id, type, subtype, title, title_ru, title_original, year, countries,
          imdb_id, imdb_rating, imdb_votes, kinopoisk_id, kinopoisk_rating, kinopoisk_votes,
          kinopub_rating_votes, kinopub_rating_percentage, views,
          poster_thumb, poster_wide, finished, created_at, updated_at,
          first_synced_at, last_synced_at
        ) VALUES (
          :id, :type, :subtype, :title, :title_ru, :title_original, :year, :countries,
          :imdb_id, :imdb_rating, :imdb_votes, :kinopoisk_id, :kinopoisk_rating, :kinopoisk_votes,
          :kinopub_rating_votes, :kinopub_rating_percentage, :views,
          :poster_thumb, :poster_wide, :finished, :created_at, :updated_at,
          :last_synced_at, :last_synced_at
        )
        ON CONFLICT(id) DO UPDATE SET
          type=excluded.type, subtype=excluded.subtype, title=excluded.title,
          title_ru=excluded.title_ru, title_original=excluded.title_original,
          year=excluded.year, countries=excluded.countries,
          imdb_id=excluded.imdb_id, imdb_rating=excluded.imdb_rating, imdb_votes=excluded.imdb_votes,
          kinopoisk_id=excluded.kinopoisk_id, kinopoisk_rating=excluded.kinopoisk_rating,
          kinopoisk_votes=excluded.kinopoisk_votes,
          kinopub_rating_votes=excluded.kinopub_rating_votes,
          kinopub_rating_percentage=excluded.kinopub_rating_percentage,
          views=excluded.views, poster_thumb=excluded.poster_thumb, poster_wide=excluded.poster_wide,
          finished=excluded.finished, created_at=excluded.created_at, updated_at=excluded.updated_at,
          last_synced_at=excluded.last_synced_at
        """,
        rows,
    )
    conn.commit()


def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {}


def save_state(state):
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))


def sync_type(conn, media_type, token_holder, state, resume):
    start_page = state.get(media_type, {}).get("last_completed_page", 0) + 1 if resume else 1
    page = start_page
    total_pages = None
    total_items_seen = 0
    while total_pages is None or page <= total_pages:
        data = fetch_page("/v1/items", {
            "type": media_type, "sort": "-created", "page": page,
        }, token_holder)
        pagination = data.get("pagination", {})
        total_pages = pagination.get("total", page)
        items = data.get("items", [])
        if not items:
            break
        upsert_items(conn, items, now_iso())
        total_items_seen += len(items)
        state[media_type] = {"last_completed_page": page, "total_pages": total_pages}
        save_state(state)
        print(f"  [{media_type}] page {page}/{total_pages} ({len(items)} items, "
              f"{total_items_seen} so far)", flush=True)
        page += 1
        time.sleep(REQUEST_DELAY)
    return total_items_seen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--types", default=",".join(ALL_TYPES),
                         help="comma-separated content types to sync")
    parser.add_argument("--resume", action="store_true",
                         help="continue from the last saved page per type instead of restarting at page 1")
    parser.add_argument("--db", default=str(DEFAULT_DB))
    parser.add_argument("--token", default=None,
                         help="access token from a live app session, if Keychain access isn't available")
    args = parser.parse_args()

    types = [t.strip() for t in args.types.split(",") if t.strip()]

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    db_path = Path(args.db)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)

    token_holder = dict(get_access_token(args.token))
    state = load_state()

    start = time.time()
    grand_total = 0
    for media_type in types:
        print(f"== {media_type} ==")
        grand_total += sync_type(conn, media_type, token_holder, state, args.resume)

    elapsed = time.time() - start
    total_rows = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]
    print(f"\nDone. {grand_total} items fetched this run, {total_rows} rows total in "
          f"{db_path} ({elapsed:.0f}s).")
    conn.close()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
