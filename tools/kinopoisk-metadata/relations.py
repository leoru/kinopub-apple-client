#!/usr/bin/env python3
"""
Per-film connection data: relations (sequels/prequels/similars/remakes/spoofs —
whatever relationType says), similars, and page 1 of reviews. Separate from the
main probe/ingest pair since this is a different concern (film-to-film graph,
not film attributes) — writes straight into kp_relations / kp_similars /
kp_reviews in data/kinopoisk.db, no raw-cache intermediate.

Defaults to the same 8 test titles as probe.py, plus Брат 2 (41520) — added
specifically to complete the Брат/Брат 2 sequel pair.

Usage:
  python3 relations.py --api-key <key>
  python3 relations.py --api-key <key> --ids 41519,41520,326
"""
import argparse
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE_URL = "https://kinopoiskapiunofficial.tech"
REQUEST_DELAY = 1.0
DATA_DIR = Path(__file__).parent / "data"
OUT_DB = DATA_DIR / "kinopoisk.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"

DEFAULT_IDS = [5235968, 1382256, 41519, 41520, 326, 5437615, 839458, 77039, 404900]


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


def ensure_film_stub(conn, kp_id):
    """kp_relations/kp_similars/kp_reviews FK kp_films — insert a bare stub if
    this id was never pulled through probe.py/ingest.py (e.g. Брат 2)."""
    conn.execute(
        "INSERT OR IGNORE INTO kp_films (kinopoisk_id, fetched_at) VALUES (?, '')",
        (kp_id,),
    )


def ingest_relations(conn, kp_id, body):
    conn.execute("DELETE FROM kp_relations WHERE kinopoisk_id=?", (kp_id,))
    for item in json.loads(body).get("items", []):
        conn.execute(
            "INSERT OR REPLACE INTO kp_relations VALUES (?,?,?,?,?,?,?)",
            (kp_id, item["kinopoiskId"], item.get("relationType"), item.get("nameRu"),
             item.get("nameEn"), item.get("nameOriginal"), item.get("posterUrl")),
        )


def ingest_similars(conn, kp_id, body):
    conn.execute("DELETE FROM kp_similars WHERE kinopoisk_id=?", (kp_id,))
    for item in json.loads(body).get("items", []):
        conn.execute(
            "INSERT OR REPLACE INTO kp_similars VALUES (?,?,?,?,?,?)",
            (kp_id, item["filmId"], item.get("nameRu"), item.get("nameEn"),
             item.get("nameOriginal"), item.get("posterUrl")),
        )


def ingest_reviews(conn, kp_id, body):
    d = json.loads(body)
    for item in d.get("items", []):
        conn.execute(
            "INSERT OR REPLACE INTO kp_reviews VALUES (?,?,?,?,?,?,?,?,?)",
            (item["kinopoiskId"], kp_id, item.get("type"), item.get("date"),
             item.get("positiveRating"), item.get("negativeRating"), item.get("author"),
             item.get("title"), item.get("description")),
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-key", default=os.environ.get("KINOPOISK_API_KEY"))
    parser.add_argument("--ids", default=None, help="comma-separated kinopoisk ids")
    args = parser.parse_args()

    if not args.api_key:
        sys.exit("Need --api-key or KINOPOISK_API_KEY.")

    ids = [int(x) for x in args.ids.split(",")] if args.ids else DEFAULT_IDS

    conn = sqlite3.connect(OUT_DB)
    conn.executescript(SCHEMA_PATH.read_text())

    for kp_id in ids:
        print(f"== {kp_id} ==")
        ensure_film_stub(conn, kp_id)
        for name, path, ingester in [
            ("relations", f"/api/v2.2/films/{kp_id}/relations", ingest_relations),
            ("similars", f"/api/v2.2/films/{kp_id}/similars", ingest_similars),
            ("reviews", f"/api/v2.2/films/{kp_id}/reviews?page=1", ingest_reviews),
        ]:
            status, body = fetch(path, args.api_key)
            print(f"  [{name}] {status} ({len(body)} bytes)")
            if status == 200:
                ingester(conn, kp_id, body)
                conn.commit()
            time.sleep(REQUEST_DELAY)

    print(f"\nDone. Written to {OUT_DB}.")
    conn.close()


if __name__ == "__main__":
    main()
