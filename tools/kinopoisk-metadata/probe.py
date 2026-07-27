#!/usr/bin/env python3
"""
Exploratory probe of the Kinopoisk Unofficial API (kinopoiskapiunofficial.tech)
against a small, hand-picked set of real kino.pub titles — a few movies, a few
series, old and new, Russian and foreign. Saves every raw response so we can
look at what actually comes back before deciding what's worth keeping in the
real schema.

Auth: needs a free API key from https://kinopoiskapiunofficial.tech (register,
copy the X-API-KEY). Pass it via --api-key or the KINOPOISK_API_KEY env var —
never hardcoded here.

Usage:
  python3 probe.py --api-key <key>
  KINOPOISK_API_KEY=<key> python3 probe.py
  python3 probe.py --api-key <key> --ids 326,689   # just these kinopoisk ids
"""
import argparse
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

BASE_URL = "https://kinopoiskapiunofficial.tech"
REQUEST_DELAY = 1.0
DATA_DIR = Path(__file__).parent / "data"
DEFAULT_DB = DATA_DIR / "probe.db"

# Hand-picked from our own kino.pub snapshot (tools/kinopub-snapshot/data/snapshot.db) —
# real ids, not guessed. Covers movie/serial x new/old x Russian/foreign.
TEST_TITLES = [
    {"kinopoisk_id": 5235968, "label": "Кентавр (2023)", "bucket": "movie/new/ru", "is_series": False},
    {"kinopoisk_id": 1382256, "label": "Проект «Конец света» (2026, US)", "bucket": "movie/new/foreign", "is_series": False},
    {"kinopoisk_id": 41519, "label": "Брат (1997)", "bucket": "movie/old/ru", "is_series": False},
    {"kinopoisk_id": 326, "label": "The Shawshank Redemption (1994)", "bucket": "movie/old/foreign", "is_series": False},
    {"kinopoisk_id": 5437615, "label": "Аутсорс (2025)", "bucket": "serial/new/ru", "is_series": True},
    {"kinopoisk_id": 839458, "label": "The Last of Us (2023)", "bucket": "serial/new/foreign", "is_series": True},
    {"kinopoisk_id": 77039, "label": "Бригада (2002)", "bucket": "serial/old/ru", "is_series": True},
    {"kinopoisk_id": 404900, "label": "Breaking Bad (2008)", "bucket": "serial/old/foreign", "is_series": True},
]

# Endpoints probed per title. `seasons` only makes sense for series.
ENDPOINTS = [
    ("details", "/api/v2.2/films/{id}"),
    ("staff", "/api/v1/staff?filmId={id}"),
    ("box_office", "/api/v2.2/films/{id}/box_office"),
    ("videos", "/api/v2.2/films/{id}/videos"),
    ("awards", "/api/v2.2/films/{id}/awards"),
]
SERIES_ONLY_ENDPOINTS = [
    ("seasons", "/api/v2.2/films/{id}/seasons"),
]

SCHEMA = """
CREATE TABLE IF NOT EXISTS probe_responses (
  kinopoisk_id INTEGER NOT NULL,
  endpoint TEXT NOT NULL,
  label TEXT,
  bucket TEXT,
  status_code INTEGER,
  raw_json TEXT,
  fetched_at TEXT NOT NULL,
  PRIMARY KEY (kinopoisk_id, endpoint)
);
"""


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def fetch(path, api_key, retries=3):
    req = urllib.request.Request(f"{BASE_URL}{path}", headers={"X-API-KEY": api_key})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.status, resp.read().decode()
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode()
        except urllib.error.URLError:
            if attempt == retries - 1:
                raise
            time.sleep(2 ** attempt)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-key", default=os.environ.get("KINOPOISK_API_KEY"))
    parser.add_argument("--ids", default=None,
                         help="comma-separated kinopoisk ids to restrict the run to")
    parser.add_argument("--db", default=str(DEFAULT_DB))
    args = parser.parse_args()

    if not args.api_key:
        sys.exit(
            "No API key. Register a free one at https://kinopoiskapiunofficial.tech "
            "and pass it with --api-key or KINOPOISK_API_KEY."
        )

    titles = TEST_TITLES
    if args.ids:
        wanted = {int(x) for x in args.ids.split(",")}
        titles = [t for t in titles if t["kinopoisk_id"] in wanted]

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(args.db)
    conn.executescript(SCHEMA)

    def save(kp_id, name, label, bucket, status, body):
        conn.execute(
            """
            INSERT INTO probe_responses (kinopoisk_id, endpoint, label, bucket, status_code, raw_json, fetched_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(kinopoisk_id, endpoint) DO UPDATE SET
              status_code=excluded.status_code, raw_json=excluded.raw_json, fetched_at=excluded.fetched_at
            """,
            (kp_id, name, label, bucket, status, body, now_iso()),
        )
        conn.commit()
        print(f"  [{name}] {status} ({len(body)} bytes)")

    for title in titles:
        kp_id = title["kinopoisk_id"]
        endpoints = ENDPOINTS + (SERIES_ONLY_ENDPOINTS if title["is_series"] else [])
        print(f"== {title['label']} ({title['bucket']}, kp={kp_id}) ==")
        staff_body = None
        for name, path_template in endpoints:
            path = path_template.format(id=kp_id)
            status, body = fetch(path, args.api_key)
            save(kp_id, name, title["label"], title["bucket"], status, body)
            if name == "staff" and status == 200:
                staff_body = body
            time.sleep(REQUEST_DELAY)

        # One representative person-detail probe per title: the first credited actor.
        if staff_body:
            try:
                actor = next(m for m in json.loads(staff_body) if m.get("professionKey") == "ACTOR")
            except StopIteration:
                actor = None
            if actor:
                person_id = actor["staffId"]
                status, body = fetch(f"/api/v1/staff/{person_id}", args.api_key)
                save(person_id, "person_detail", f"{actor['nameRu']} (cast of {title['label']})",
                     "person_sample", status, body)
                time.sleep(REQUEST_DELAY)

    print(f"\nSaved to {args.db}. Inspect with:\n"
          f"  sqlite3 {args.db} \"SELECT kinopoisk_id, endpoint, status_code, length(raw_json) FROM probe_responses\"")
    conn.close()


if __name__ == "__main__":
    main()
