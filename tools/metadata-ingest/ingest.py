#!/usr/bin/env python3
"""Build the unified metadata record from every local dump. One command.

    python3 ingest.py                # everything, idempotent — safe to re-run
    python3 ingest.py --only tvoe    # one source
    python3 ingest.py --stats        # report what is in the record now
    python3 ingest.py --fresh        # rebuild from scratch

Re-running is the normal case: writes are upserts keyed by source ids, so a
second pass changes nothing. Order matters once — kino.pub goes first so it
seeds the spine that the other sources attach to.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DEFAULT_DB, connect  # noqa: E402
from sources import ingest_kinopoisk, ingest_kinopub, ingest_tvoe  # noqa: E402

SOURCES = {
    "kinopub": ingest_kinopub,     # first: seeds the spine
    "kinopoisk": ingest_kinopoisk,  # attaches by kinopoisk id / imdb id
    "tvoe": ingest_tvoe,           # attaches by original title + year
}


def report(conn) -> None:
    print("\nrecord:")
    tables = ["title", "title_external_id", "person", "person_external_id", "title_credit",
              "image", "rating", "trailer", "badge", "episode", "award",
              "genre", "country", "synopsis",
              "title_copy", "copy_video", "copy_segment", "raw_payload"]
    for table in tables:
        count = conn.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        print(f"  {table:<20} {count:>9,}")

    print("\ntitles by source:")
    for row in conn.execute(
        "SELECT namespace, count(*) n FROM title_external_id GROUP BY namespace ORDER BY n DESC"
    ):
        print(f"  {row['namespace']:<20} {row['n']:>9,}")

    print("\nhow non-kinopub ids attached:")
    for row in conn.execute(
        "SELECT namespace, method, count(*) n FROM title_external_id"
        " WHERE namespace NOT IN ('kinopub') GROUP BY namespace, method ORDER BY n DESC LIMIT 10"
    ):
        print(f"  {row['namespace']:<12} {row['method']:<22} {row['n']:>8,}")

    print("\ncoverage (titles that have at least one):")
    for label, query in (
        ("external id besides kinopub",
         "SELECT count(DISTINCT title_id) FROM title_external_id WHERE namespace<>'kinopub'"),
        ("any rating", "SELECT count(DISTINCT title_id) FROM rating"),
        ("any credit", "SELECT count(DISTINCT title_id) FROM title_credit"),
        ("stable artwork", "SELECT count(DISTINCT title_id) FROM image WHERE stable=1"),
        ("episodes", "SELECT count(DISTINCT title_id) FROM episode"),
        ("a copy on 2+ platforms",
         "SELECT count(*) FROM (SELECT title_id FROM title_copy GROUP BY title_id"
         " HAVING count(DISTINCT platform) > 1)"),
        ("copies with skip markers",
         "SELECT count(DISTINCT copy_id) FROM copy_segment"),
    ):
        print(f"  {label:<28} {conn.execute(query).fetchone()[0]:>9,}")

    print("\nlast runs:")
    for row in conn.execute(
        "SELECT source, raw_rows, titles_new, titles_seen, finished_at, note"
        " FROM ingest_run ORDER BY id DESC LIMIT 6"
    ):
        state = row["note"] or ("ok" if row["finished_at"] else "unfinished")
        print(f"  {row['source']:<12} raw={row['raw_rows']:>7,} new={row['titles_new']:>7,}"
              f" matched={row['titles_seen']:>7,}  {state}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--only", choices=sorted(SOURCES), action="append")
    parser.add_argument("--limit", type=int, help="cap kino.pub rows, for a quick smoke run")
    parser.add_argument("--fresh", action="store_true", help="delete the record and rebuild")
    parser.add_argument("--stats", action="store_true", help="report only, import nothing")
    args = parser.parse_args()

    if args.fresh and args.db.exists():
        for suffix in ("", "-wal", "-shm"):
            Path(str(args.db) + suffix).unlink(missing_ok=True)
        print(f"removed {args.db}")

    conn = connect(args.db)

    if args.stats:
        report(conn)
        return 0

    # Dict order is the dependency order; --only preserves it rather than the
    # order the flags were typed, so kino.pub still seeds first when both run.
    selected = [name for name in SOURCES if not args.only or name in args.only]

    for name in selected:
        print(f"→ {name}")
        kwargs = {"limit": args.limit} if name == "kinopub" and args.limit else {}
        run = SOURCES[name](conn, **kwargs)
        conn.commit()
        print(f"  raw={run.raw:,}  new titles={run.new:,}  matched={run.seen:,}")

    report(conn)
    print(f"\n{args.db}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
