#!/usr/bin/env python3
"""Rotten Tomatoes + Metacritic, one request per title. Lazy, never a sweep.

    export OMDB_API_KEY=...
    python3 fetch_omdb.py --titles 41,905     # exactly these
    python3 fetch_omdb.py --limit 200         # the 200 most-voted still missing

**1 000 requests/day on the free tier.** 53 210 titles is 53 days for one pass,
so there is no `--sweep` here at all — the budget decides the policy. Fetch what
a page needs; coverage accumulates from use.

The only reason this provider exists for us is `Ratings[]`: Rotten Tomatoes and
Metacritic in one call, which nothing else we integrate has. IMDb rating and
votes are already in the record from the kino.pub snapshot, so those are stored
as a cross-check under a separate source name rather than overwriting.

Sheet, including what we deliberately skip: docs/providers/omdb.md
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DEFAULT_DB, add_rating, connect, now, store_raw  # noqa: E402

BASE = "https://www.omdbapi.com/"

# `Source` string → (our source name, scale). Three scales in one array, as text.
RATING_SOURCES = {
    "Internet Movie Database": ("imdb:omdb", 10.0),
    "Rotten Tomatoes": ("rotten_tomatoes", 100.0),
    "Metacritic": ("metacritic", 100.0),
}


def parse_number(raw):
    """OMDb ships every number as a string: "9.3", "2,900,123", "91%", "80/100"."""
    if not raw or raw == "N/A":
        return None
    match = re.search(r"[\d.]+", str(raw).replace(",", ""))
    return float(match.group()) if match else None


def get(api_key, params, *, timeout=20):
    query = {"apikey": api_key, "r": "json", **params}
    url = f"{BASE}?{urllib.parse.urlencode(query)}"
    request = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "kinopub-metadata-ingest/1.0 (+tools/metadata-ingest)",
    })
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"), strict=False)
    except urllib.error.HTTPError as error:
        return {"Response": "False", "Error": f"HTTP {error.code}"}
    except Exception as error:
        return None  # transient — not an answer, do not log it as one


def derive(conn, title_id, payload):
    """Ratings only. Everything else OMDb returns has a better source already."""
    for entry in payload.get("Ratings") or []:
        mapped = RATING_SOURCES.get(entry.get("Source"))
        if not mapped:
            continue
        source, scale = mapped
        add_rating(conn, title_id, source, parse_number(entry.get("Value")), None, scale=scale)

    # Metascore duplicates the Metacritic row above but is present on records
    # that omit the array; harmless as a second writer into the same key.
    add_rating(conn, title_id, "metacritic", parse_number(payload.get("Metascore")), None,
               scale=100.0)
    # Cross-check, deliberately under its own name so it never overwrites the
    # kino.pub snapshot's IMDb numbers.
    add_rating(conn, title_id, "imdb:omdb", parse_number(payload.get("imdbRating")),
               int(parse_number(payload.get("imdbVotes")) or 0) or None)

    box_office = parse_number(payload.get("BoxOffice"))
    if box_office:
        conn.execute(
            "INSERT OR IGNORE INTO synopsis(title_id,source,lang,variant,text)"
            " VALUES (?,'omdb','en','box_office',?)", (title_id, str(int(box_office))),
        )


def pending(conn, *, limit=None, titles=None, refresh=False):
    asked = "" if refresh else (
        " AND NOT EXISTS (SELECT 1 FROM fetch_log f WHERE f.source='omdb'"
        " AND f.endpoint='title' AND f.key=e.value)")
    chosen = ""
    if titles:
        chosen = f" AND e.title_id IN ({','.join(str(int(v)) for v in titles)})"
    query = (
        "SELECT e.title_id, e.value AS imdb,"
        " (SELECT votes FROM rating r WHERE r.title_id=e.title_id AND r.source='imdb') AS votes"
        " FROM title_external_id e"
        f" WHERE e.namespace='imdb'{asked}{chosen}"
        " ORDER BY votes IS NULL, votes DESC"
    )
    if limit:
        query += f" LIMIT {int(limit)}"
    return conn.execute(query).fetchall()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--api-key", default=os.environ.get("OMDB_API_KEY"))
    parser.add_argument("--titles")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--refresh", action="store_true")
    # One connection, ~3 req/s: the daily cap is the real limit, not the rate.
    parser.add_argument("--rps", type=float, default=3.0)
    args = parser.parse_args()

    if not args.api_key:
        parser.error("need an OMDb key: --api-key or OMDB_API_KEY "
                     "(free tier, 1000/day, omdbapi.com/apikey.aspx)")
    titles = [part for part in (args.titles or "").split(",") if part.strip()]
    if not titles and not args.limit:
        parser.error("say what to fetch: --titles or --limit. There is no sweep at 1000/day.")

    conn = connect(args.db)
    queue = pending(conn, limit=args.limit, titles=titles, refresh=args.refresh)
    if not queue:
        print("nothing pending")
        return 0

    print(f"{len(queue):,} titles · {args.rps} rps · daily cap is 1 000")
    interval = 1.0 / args.rps if args.rps else 0.0
    ok = missing = failed = 0

    for index, row in enumerate(queue, start=1):
        payload = get(args.api_key, {"i": row["imdb"], "plot": "short"})
        if payload is None:
            failed += 1
            continue

        # Errors arrive as HTTP 200 with Response:"False" — the single most
        # important thing about this API. Trusting the status code records a
        # quota wall as a successful empty answer.
        if payload.get("Response") == "False":
            error = payload.get("Error") or "unknown"
            # Only "not found" is an answer *about this title*. A bad key or a
            # spent quota is an answer about us, and logging either as a 404
            # would poison fetch_log so the title is never asked again.
            if "not found" not in error.lower():
                print(f"  stopped at {index:,}: {error}")
                conn.commit()
                break
            missing += 1
            conn.execute(
                "INSERT OR REPLACE INTO fetch_log(source,endpoint,key,status,fetched_at,"
                "ttl_seconds,note) VALUES ('omdb','title',?,404,?,?,?)",
                (row["imdb"], now(), 60 * 60 * 24 * 30, error),
            )
        else:
            store_raw(conn, "omdb", "title", row["imdb"], payload, via="fetch")
            derive(conn, row["title_id"], payload)
            ok += 1
            conn.execute(
                "INSERT OR REPLACE INTO fetch_log(source,endpoint,key,status,fetched_at,"
                "ttl_seconds,note) VALUES ('omdb','title',?,200,?,?,NULL)",
                (row["imdb"], now(), 60 * 60 * 24 * 30),
            )

        if index % 50 == 0:
            conn.commit()
            print(f"  {index:,}/{len(queue):,}  ok={ok:,} missing={missing:,} fail={failed:,}")
        if interval:
            time.sleep(interval)

    conn.commit()
    print(f"\nok={ok:,}  not-found={missing:,}  network-fail={failed:,}")
    for label, query in (
        ("Rotten Tomatoes", "SELECT count(*) FROM rating WHERE source='rotten_tomatoes'"),
        ("Metacritic", "SELECT count(*) FROM rating WHERE source='metacritic'"),
        ("IMDb cross-check", "SELECT count(*) FROM rating WHERE source='imdb:omdb'"),
        ("asked in total", "SELECT count(*) FROM fetch_log WHERE source='omdb'"),
    ):
        print(f"  {label:<20} {conn.execute(query).fetchone()[0]:>8,}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
