#!/usr/bin/env python3
"""Read TMDB's free daily id dumps. Breadth without spending a single API call.

    python3 fetch_tmdb_exports.py                    # movie + tv, yesterday's files
    python3 fetch_tmdb_exports.py --kind person      # people
    python3 fetch_tmdb_exports.py --date 08-10-2026

TMDB publishes one gzipped JSON-lines file per entity type per day at
`files.tmdb.org/p/exports/`. Each line is one entity — id, original title,
popularity, adult and video flags. No auth, no quota, no proxy.

**What this is for:** knowing that an id exists, what it is called originally,
and how popular it is. That is exactly the breadth half of coverage — enough to
resolve, rank, and decide what is worth a detail request.

**What it is not:** a substitute for detail fetches. There are no credits, no
artwork, no ratings, no dates in these files. Depth still costs one request per
title, which is why depth is fetched lazily and only for titles someone opened.
"""

from __future__ import annotations

import argparse
import gzip
import io
import json
import sys
import urllib.request
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DEFAULT_DB, connect, now  # noqa: E402

# Through the worker: files.tmdb.org resolves to 127.0.0.1 on hijacked networks,
# exactly like image.tmdb.org. The dumps need no auth — the proxy is transport.
BASE = "https://kinopub-tmdb-proxy.traneblow1nd.workers.dev/p/exports"
KINDS = {"movie": "movie_ids", "tv": "tv_series_ids", "person": "person_ids"}

SCHEMA = """
CREATE TABLE IF NOT EXISTS tmdb_export (
  kind           TEXT NOT NULL,
  tmdb_id        INTEGER NOT NULL,
  original_title TEXT,
  popularity     REAL,
  adult          INTEGER,
  video          INTEGER,
  exported_on    TEXT NOT NULL,
  PRIMARY KEY (kind, tmdb_id)
);
CREATE INDEX IF NOT EXISTS idx_tmdb_export_pop ON tmdb_export(kind, popularity DESC);
"""


def download(kind: str, on: date) -> bytes:
    url = f"{BASE}/{KINDS[kind]}_{on.strftime('%m_%d_%Y')}.json.gz"
    request = urllib.request.Request(url, headers={
        "User-Agent": "kinopub-metadata-ingest/1.0 (+tools/metadata-ingest)",
    })
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def load(conn, kind: str, blob: bytes, on: date) -> int:
    stamp = on.isoformat()
    rows, count = [], 0
    with gzip.open(io.BytesIO(blob), "rt", encoding="utf-8") as stream:
        for line in stream:
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)
            rows.append((kind, entry.get("id"),
                         entry.get("original_title") or entry.get("original_name")
                         or entry.get("name"),
                         entry.get("popularity"),
                         1 if entry.get("adult") else 0,
                         1 if entry.get("video") else 0, stamp))
            if len(rows) >= 5000:
                conn.executemany(
                    "INSERT OR REPLACE INTO tmdb_export(kind,tmdb_id,original_title,popularity,"
                    "adult,video,exported_on) VALUES (?,?,?,?,?,?,?)", rows)
                count += len(rows)
                rows.clear()
    if rows:
        conn.executemany(
            "INSERT OR REPLACE INTO tmdb_export(kind,tmdb_id,original_title,popularity,"
            "adult,video,exported_on) VALUES (?,?,?,?,?,?,?)", rows)
        count += len(rows)
    conn.commit()
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--kind", action="append", choices=sorted(KINDS))
    parser.add_argument("--date", help="MM-DD-YYYY; defaults to yesterday UTC")
    args = parser.parse_args()

    if args.date:
        month, day, year = (int(part) for part in args.date.split("-"))
        on = date(year, month, day)
    else:
        # The day's file appears after ~08:00 UTC, so yesterday is always safe.
        on = date.today() - timedelta(days=1)

    conn = connect(args.db)
    conn.executescript(SCHEMA)

    for kind in args.kind or ["movie", "tv"]:
        try:
            blob = download(kind, on)
        except Exception as error:
            print(f"{kind}: {error}")
            continue
        count = load(conn, kind, blob, on)
        conn.execute(
            "INSERT OR REPLACE INTO fetch_log(source,endpoint,key,status,fetched_at,ttl_seconds,"
            "note) VALUES ('tmdb','export',?,200,?,?,?)",
            (f"{kind}:{on.isoformat()}", now(), 60 * 60 * 24, f"{count} rows"),
        )
        conn.commit()
        print(f"{kind:<7} {count:>9,} ids  ({on})")

    print()
    for row in conn.execute(
        "SELECT kind, count(*) n, max(exported_on) day FROM tmdb_export GROUP BY kind"
    ):
        print(f"  {row['kind']:<8} {row['n']:>9,}  as of {row['day']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
