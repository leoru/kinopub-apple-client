#!/usr/bin/env python3
"""IMDb's official dumps. Every rating we will ever need, in one download.

    python3 import_imdb_datasets.py              # ratings + episode map
    python3 import_imdb_datasets.py --only ratings

Two files, published daily by IMDb, no key and no quota:

  title.ratings.tsv.gz   ~8 MB   tconst, averageRating, numVotes  (~1.5M rows)
  title.episode.tsv.gz  ~30 MB   tconst, parentTconst, season, episode

Together they give **per-title and per-episode IMDb ratings for the entire
catalogue**, which is the thing we kept planning to buy one request at a time.
53 210 titles through OMDb is 53 days at 1 000/day; this is one download.

Downloaded copies are cached under `data/imdb/` and reused, so re-running costs
nothing. `--refresh` re-downloads.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import io
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DEFAULT_DB, Run, add_rating, connect, now  # noqa: E402

BASE = "https://datasets.imdbws.com"
FILES = {
    "ratings": "title.ratings.tsv.gz",
    "episodes": "title.episode.tsv.gz",
}
NULL = "\\N"


def download(name: str, cache_dir: Path, refresh: bool) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    target = cache_dir / FILES[name]
    if target.exists() and not refresh:
        return target
    request = urllib.request.Request(f"{BASE}/{FILES[name]}", headers={
        "User-Agent": "kinopub-metadata-ingest/1.0 (+tools/metadata-ingest)",
    })
    with urllib.request.urlopen(request, timeout=300) as response:
        target.write_bytes(response.read())
    return target


def rows(path: Path):
    """IMDb ships TSV with literal `\\N` for null and no quoting."""
    with gzip.open(path, "rt", encoding="utf-8", newline="") as stream:
        for row in csv.DictReader(stream, delimiter="\t", quoting=csv.QUOTE_NONE):
            yield {k: (None if v == NULL else v) for k, v in row.items()}


def known_imdb_ids(conn) -> dict[str, int]:
    """tconst → our title id, for everything the record already knows about."""
    return {row["value"]: row["title_id"] for row in conn.execute(
        "SELECT value, title_id FROM title_external_id WHERE namespace='imdb'")}


def import_ratings(conn, path: Path, wanted: dict[str, int]) -> Run:
    run = Run(conn, "imdb:ratings")
    for index, row in enumerate(rows(path), start=1):
        run.raw = index
        title_id = wanted.get(row["tconst"])
        if title_id is None:
            continue
        add_rating(conn, title_id, "imdb", float(row["averageRating"]),
                   int(row["numVotes"]))
        run.seen += 1
        if run.seen % 20000 == 0:
            conn.commit()
    conn.commit()
    run.finish()
    return run


def import_episode_ratings(conn, episode_path: Path, ratings_path: Path,
                           wanted: dict[str, int]) -> Run:
    """Join the two files: episode tconst → parent series → season/episode.

    Only episodes whose *parent* we hold are kept, so this stays proportional to
    our catalogue rather than to IMDb's.
    """
    run = Run(conn, "imdb:episodes")

    # Pass one: which episode ids belong to series we know, and where they sit.
    placement: dict[str, tuple[int, int, int]] = {}
    for index, row in enumerate(rows(episode_path), start=1):
        run.raw = index
        title_id = wanted.get(row["parentTconst"])
        if title_id is None or not row["seasonNumber"] or not row["episodeNumber"]:
            continue
        try:
            placement[row["tconst"]] = (title_id, int(row["seasonNumber"]),
                                        int(row["episodeNumber"]))
        except ValueError:
            continue

    # Pass two: attach the rating to each of those episodes.
    for row in rows(ratings_path):
        found = placement.get(row["tconst"])
        if not found:
            continue
        title_id, season, episode = found
        add_rating(conn, title_id, "imdb", float(row["averageRating"]),
                   int(row["numVotes"]), season=season, episode=episode)
        run.seen += 1
        if run.seen % 20000 == 0:
            conn.commit()
    conn.commit()
    run.finish()
    return run


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--only", choices=("ratings", "episodes"), action="append")
    parser.add_argument("--refresh", action="store_true", help="re-download the dumps")
    args = parser.parse_args()

    conn = connect(args.db)
    cache = args.db.parent / "imdb"
    wanted = known_imdb_ids(conn)
    print(f"{len(wanted):,} IMDb ids in the record")

    selected = args.only or ["ratings", "episodes"]
    ratings_path = download("ratings", cache, args.refresh)
    print(f"  {FILES['ratings']:<24} {ratings_path.stat().st_size / 1e6:>6.1f} MB")

    if "ratings" in selected:
        run = import_ratings(conn, ratings_path, wanted)
        print(f"→ title ratings   scanned={run.raw:,}  matched={run.seen:,}")

    if "episodes" in selected:
        episode_path = download("episodes", cache, args.refresh)
        print(f"  {FILES['episodes']:<24} {episode_path.stat().st_size / 1e6:>6.1f} MB")
        run = import_episode_ratings(conn, episode_path, ratings_path, wanted)
        print(f"→ episode ratings scanned={run.raw:,}  matched={run.seen:,}")

    conn.execute(
        "INSERT OR REPLACE INTO fetch_log(source,endpoint,key,status,fetched_at,ttl_seconds,note)"
        " VALUES ('imdb','datasets','all',200,?,?,'official dumps')",
        (now(), 60 * 60 * 24),
    )
    conn.commit()

    print()
    for label, query in (
        ("titles with an IMDb rating",
         "SELECT count(*) FROM rating WHERE source='imdb' AND season IS NULL"),
        ("episodes with an IMDb rating",
         "SELECT count(*) FROM rating WHERE source='imdb' AND season IS NOT NULL"),
        ("series covered per-episode",
         "SELECT count(DISTINCT title_id) FROM rating WHERE source='imdb'"
         " AND season IS NOT NULL"),
    ):
        print(f"  {label:<30} {conn.execute(query).fetchone()[0]:>9,}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
