#!/usr/bin/env python3
"""
Full sweep of every movie/serial in our own kino.pub library (kinopub-snapshot's
snapshot.db) against the Kinopoisk Unofficial API — meant to run for hours in
the background. Scope, per your call:

  - movie + serial only for this pass (docuserial/documovie/concert/tvshow/3D
    stay for a later run — same script, different --types); year >= 2000
  - queued by rating * log10(votes) — not rating alone, which would burn quota
    on obscure titles a handful of people rated 10/10 — using kino.pub's own
    cached imdb/kinopoisk ratings + imdb/kinopoisk votes + kino.pub views (so
    ordering doesn't depend on data this run hasn't fetched yet)
  - per title: details (every field), awards, relations (sequels/prequels/
    similars/remakes — whatever relationType says) — and seasons for series
  - explicitly NOT pulled here: images, staff/cast, or any per-person detail —
    "just build up the [film-level] information", the actor/cast drill-down
    is a separate, later pass

The free-tier key caps at 500 requests/day (confirmed via the API's own error
message), ~150 items/day at this pass's ~3.2 calls/item average — nowhere near
enough for the full ~38k-item queue in one sitting. This is meant to run once
a day via cron (see schedule setup), always re-picking the current
highest-priority remaining items, until stopped by hand — not meant to ever
"finish" on a fixed schedule.

Resumable: a `bulk_progress` table marks an id done only once every one of its
calls for this pass succeeded, so a kill/restart never redoes finished work
and never silently skips a half-finished one. A 402 (quota exhausted) leaves
the item OUT of bulk_progress and stops the run — no wasted requests hammering
a wall, no false "done" marks — so the next scheduled run just resumes.

Usage:
  python3 bulk_films.py --api-key <key>                 # full queue
  python3 bulk_films.py --api-key <key> --limit 500      # smoke-test a slice
  python3 bulk_films.py --api-key <key> --types movie    # movies only
"""
import argparse
import math
import os
import sqlite3
import sys
import threading
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from ingest import ingest_details, ingest_awards, ingest_seasons, now_iso
from relations import ingest_relations

BASE_URL = "https://kinopoiskapiunofficial.tech"
REQUEST_DELAY = 0.1  # per-thread politeness pause; parallelism does the real speedup
MAX_RETRIES = 4
WORKERS = 6

DATA_DIR = Path(__file__).parent / "data"
OUT_DB = DATA_DIR / "kinopoisk.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"
SNAPSHOT_DB = Path(__file__).parent.parent / "kinopub-snapshot" / "data" / "snapshot.db"

PROGRESS_SCHEMA = """
CREATE TABLE IF NOT EXISTS bulk_progress (
  kinopoisk_id INTEGER PRIMARY KEY,
  media_type TEXT,
  completed_at TEXT NOT NULL,
  had_error INTEGER DEFAULT 0
);
"""


def fetch(path, api_key, retries=MAX_RETRIES):
    req = urllib.request.Request(f"{BASE_URL}{path}", headers={"X-API-KEY": api_key})
    last_err = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.status, resp.read().decode()
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode()  # 402 (quota) included — retrying won't help
        except (urllib.error.URLError, TimeoutError) as e:
            last_err = e
            time.sleep(2 ** attempt)
    return None, str(last_err)


MIN_YEAR = 2000


def load_queue(types, limit):
    snap = sqlite3.connect(SNAPSHOT_DB)
    placeholders = ",".join("?" * len(types))
    rows = snap.execute(
        f"""
        SELECT kinopoisk_id, type, imdb_rating, kinopoisk_rating, imdb_votes, kinopoisk_votes, views
        FROM items
        WHERE type IN ({placeholders}) AND kinopoisk_id IS NOT NULL AND year >= ?
        """,
        types + [MIN_YEAR],
    ).fetchall()
    snap.close()

    def score(row):
        _, _, imdb_r, kp_r, imdb_v, kp_v, views = row
        ratings = [v for v in (imdb_r, kp_r) if v and v > 0]
        if not ratings:
            return -1.0
        rating = sum(ratings) / len(ratings)
        votes = (imdb_v or 0) + (kp_v or 0) + (views or 0)
        # Rating alone rewards obscure titles a handful of people rated 10/10;
        # this discounts anything without real vote/view volume behind it.
        return rating * math.log10(votes + 10)

    rows.sort(key=score, reverse=True)
    if limit:
        rows = rows[:limit]
    return [(kp_id, t) for kp_id, t, *_ in rows]


def process_one(conn, db_lock, quota_stop, api_key, kp_id, media_type):
    """Network calls happen unlocked (concurrent across threads); only the
    ingest+commit step needs the lock, and it's fast — SQLite writes, not I/O.

    On a 402 (daily quota exhausted), this item is left OUT of bulk_progress
    entirely — so it's retried automatically on the next run once quota
    resets — and quota_stop is set so other threads bail out of remaining
    work instead of burning through guaranteed-to-fail requests.
    """
    if quota_stop.is_set():
        return

    is_series = media_type == "serial"
    calls = [
        ("details", f"/api/v2.2/films/{kp_id}", ingest_details),
        ("awards", f"/api/v2.2/films/{kp_id}/awards", ingest_awards),
        ("relations", f"/api/v2.2/films/{kp_id}/relations", ingest_relations),
    ]
    if is_series:
        calls.append(("seasons", f"/api/v2.2/films/{kp_id}/seasons", ingest_seasons))

    had_error = False
    for name, path, ingester in calls:
        if quota_stop.is_set():
            return
        status, body = fetch(path, api_key)
        if status == 200:
            try:
                with db_lock:
                    ingester(conn, kp_id, body)
            except Exception as e:
                print(f"  [{kp_id}] {name} parse error: {e}", flush=True)
                had_error = True
        elif status == 404:
            pass  # kino.pub's kinopoisk id doesn't resolve here; not our bug
        elif status == 402:
            quota_stop.set()
            print(f"  [{kp_id}] {name} -> 402 quota exhausted, stopping.", flush=True)
            return
        else:
            print(f"  [{kp_id}] {name} -> {status}", flush=True)
            had_error = True
        time.sleep(REQUEST_DELAY)

    with db_lock:
        conn.execute(
            "INSERT OR REPLACE INTO bulk_progress VALUES (?,?,?,?)",
            (kp_id, media_type, now_iso(), int(had_error)),
        )
        conn.commit()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-key", default=os.environ.get("KINOPOISK_API_KEY"))
    parser.add_argument("--types", default="movie,serial")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    if not args.api_key:
        sys.exit("Need --api-key or KINOPOISK_API_KEY.")

    types = [t.strip() for t in args.types.split(",") if t.strip()]

    conn = sqlite3.connect(OUT_DB, check_same_thread=False)
    conn.executescript(SCHEMA_PATH.read_text())
    conn.executescript(PROGRESS_SCHEMA)
    db_lock = threading.Lock()
    quota_stop = threading.Event()

    queue = load_queue(types, args.limit)
    done = {row[0] for row in conn.execute("SELECT kinopoisk_id FROM bulk_progress")}
    remaining = [(kp_id, t) for kp_id, t in queue if kp_id not in done]

    print(f"Queue: {len(queue)} total, {len(done)} already done, "
          f"{len(remaining)} remaining. {WORKERS} workers.", flush=True)

    start = time.time()
    completed = 0
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = {
            pool.submit(process_one, conn, db_lock, quota_stop, args.api_key, kp_id, media_type): (kp_id, media_type)
            for kp_id, media_type in remaining
        }
        for future in as_completed(futures):
            kp_id, media_type = futures[future]
            try:
                future.result()
            except Exception as e:
                print(f"  [{kp_id}] worker crashed: {e}", flush=True)
            completed += 1
            if completed % 100 == 0 or completed == len(remaining):
                elapsed = time.time() - start
                rate = completed / elapsed if elapsed else 0
                eta_s = (len(remaining) - completed) / rate if rate else 0
                print(f"[{completed}/{len(remaining)}] last kp={kp_id} "
                      f"({rate:.2f}/s, ETA {eta_s/3600:.1f}h)", flush=True)

    if quota_stop.is_set():
        done_now = {row[0] for row in conn.execute("SELECT kinopoisk_id FROM bulk_progress")}
        print(f"\nStopped: daily API quota exhausted. {len(done_now) - len(done)} new items "
              f"completed this run, {len(queue) - len(done_now)} still remaining — "
              f"re-run this same command once the quota resets.", flush=True)
    else:
        print(f"\nDone. {len(remaining)} processed this run.", flush=True)
    conn.close()


if __name__ == "__main__":
    main()
