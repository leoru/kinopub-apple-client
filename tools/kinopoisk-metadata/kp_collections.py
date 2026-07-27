#!/usr/bin/env python3
"""
Kinopoisk's named top-level collections (/api/v2.2/films/collections?type=X) —
a completely different concern from per-film data: one row per collection,
many films each. Writes to kp_collections / kp_collection_films.

The `type` enum is undocumented and NOT the same as kinopoisk.ru's own website
list slugs (oscars_2022, hbo_best, etc. all 400 against this endpoint — those
live only on the site itself, behind a Yandex login wall, not this API).
Confirmed-working values so far, found by trial: TOP_250_MOVIES,
TOP_250_TV_SHOWS, FAMILY, VAMPIRE_THEME. ~25 other guesses (genres, other
named lists) all rejected — the real enum is small and mostly undiscovered.
Pass more candidates with --types as you find them.

Usage:
  python3 kp_collections.py --api-key <key>
  python3 kp_collections.py --api-key <key> --types TOP_250_MOVIES,FAMILY
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
OUT_DB = DATA_DIR / "kinopoisk.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"

CONFIRMED_TYPES = ["TOP_250_MOVIES", "TOP_250_TV_SHOWS", "FAMILY", "VAMPIRE_THEME"]


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
    parser.add_argument("--types", default=",".join(CONFIRMED_TYPES))
    args = parser.parse_args()

    if not args.api_key:
        sys.exit("Need --api-key or KINOPOISK_API_KEY.")

    types = [t.strip() for t in args.types.split(",") if t.strip()]

    conn = sqlite3.connect(OUT_DB)
    conn.executescript(SCHEMA_PATH.read_text())

    for coll_type in types:
        print(f"== {coll_type} ==")
        rank = 0
        page = 1
        total_pages = None
        conn.execute("DELETE FROM kp_collection_films WHERE collection_type=?", (coll_type,))
        while total_pages is None or page <= total_pages:
            status, body = fetch(
                f"/api/v2.2/films/collections?type={coll_type}&page={page}", args.api_key
            )
            if status != 200:
                print(f"  page {page} -> {status} ({body[:120]})")
                break
            d = json.loads(body)
            total_pages = d.get("totalPages", page)
            conn.execute(
                "INSERT OR REPLACE INTO kp_collections VALUES (?,?,?)",
                (coll_type, d.get("total"), now_iso()),
            )
            for item in d.get("items", []):
                rank += 1
                conn.execute(
                    "INSERT OR REPLACE INTO kp_collection_films VALUES (?,?,?,?,?,?,?,?,?)",
                    (coll_type, item["kinopoiskId"], rank, item.get("nameRu"), item.get("nameEn"),
                     item.get("nameOriginal"), item.get("year"), item.get("ratingKinopoisk"),
                     item.get("ratingImdb")),
                )
            conn.commit()
            print(f"  page {page}/{total_pages} ({len(d.get('items', []))} films)")
            page += 1
            time.sleep(REQUEST_DELAY)

    print(f"\nDone. Written to {OUT_DB}.")
    conn.close()


if __name__ == "__main__":
    main()
