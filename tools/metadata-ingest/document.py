#!/usr/bin/env python3
"""Build the JSON document the client gets. One title, one object.

    python3 document.py 56                    # by kino.pub id, to stdout
    python3 document.py --export data/docs    # every resolved title, as files

This is the API's payload, generated from the record and then **stored as JSON**
rather than re-assembled per request. Two reasons, and the second is the real
one:

1. Serving is a key lookup, not a dozen joins.
2. **The stored document is also the log.** When a field looks wrong, the thing
   the client received is on disk verbatim, next to the raw provider payloads
   that produced it. No reconstructing what the answer *would have been* under
   the schema as it was three commits ago.

The schema stays free to churn underneath — it is a draft and will keep moving.
The document is the contract, and it is deliberately fat: everything we hold
goes out, and trimming happens later, once it is clear what the client ignores.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DEFAULT_DB, connect, now  # noqa: E402

VERSION = 1


def _rows(conn, query, *params):
    return [dict(row) for row in conn.execute(query, params)]


def build(conn, title_id: int) -> dict | None:
    title = conn.execute("SELECT * FROM title WHERE id=?", (title_id,)).fetchone()
    if not title:
        return None

    ids = {}
    for row in conn.execute(
        "SELECT namespace, value, confidence, method FROM title_external_id WHERE title_id=?",
        (title_id,),
    ):
        ids[row["namespace"]] = {"value": row["value"], "confidence": row["confidence"],
                                 "method": row["method"]}

    # Artwork is grouped by kind and ordered by how much we trust the source for
    # that kind — the precedence table from the policy, applied here rather than
    # left to the client.
    artwork: dict[str, list] = {}
    for row in conn.execute(
        "SELECT kind, source, url, lang, width, height, color_top, color_bot"
        " FROM image WHERE title_id=? ORDER BY kind,"
        " CASE source WHEN 'tvoe' THEN 0 WHEN 'tmdb' THEN 1 WHEN 'kinopoisk' THEN 2"
        "             ELSE 3 END, width DESC", (title_id,),
    ):
        artwork.setdefault(row["kind"], []).append({
            "source": row["source"], "url": row["url"], "lang": row["lang"],
            "width": row["width"], "height": row["height"],
            "color": [row["color_top"], row["color_bot"]]
            if row["color_top"] else None,
        })

    ratings = [dict(row) for row in conn.execute(
        "SELECT source, value, votes, scale, season, episode, changed_at"
        " FROM rating WHERE title_id=? AND season IS NULL ORDER BY votes DESC NULLS LAST"
        if False else
        "SELECT source, value, votes, scale, changed_at FROM rating"
        " WHERE title_id=? AND season IS NULL ORDER BY votes IS NULL, votes DESC",
        (title_id,))]

    seasons = _rows(conn, "SELECT number, name, synopsis, air_date, end_date, episode_cnt,"
                          " poster, source FROM season WHERE title_id=? ORDER BY number",
                    title_id)
    for season in seasons:
        season["episodes"] = _rows(
            conn, "SELECT number, name_ru, name_en, synopsis, air_date, runtime, still, source"
                  " FROM episode WHERE title_id=? AND season=? ORDER BY number",
            title_id, season["number"])
        season["ratings"] = _rows(
            conn, "SELECT source, value, votes, scale, episode FROM rating"
                  " WHERE title_id=? AND season=? ORDER BY episode", title_id, season["number"])

    # Episodes whose season has no row of its own still have to be reachable —
    # IMDb's dump gives per-episode ratings for series TMDB never described.
    known = {s["number"] for s in seasons}
    orphan = _rows(conn, "SELECT DISTINCT season FROM rating WHERE title_id=?"
                         " AND season IS NOT NULL", title_id)
    for row in orphan:
        if row["season"] in known:
            continue
        seasons.append({
            "number": row["season"], "name": None, "synopsis": None, "air_date": None,
            "end_date": None, "episode_cnt": None, "poster": None, "source": "imdb",
            "episodes": _rows(conn, "SELECT number, name_ru, name_en, synopsis, air_date,"
                                    " runtime, still, source FROM episode"
                                    " WHERE title_id=? AND season=? ORDER BY number",
                              title_id, row["season"]),
            "ratings": _rows(conn, "SELECT source, value, votes, scale, episode FROM rating"
                                   " WHERE title_id=? AND season=? ORDER BY episode",
                             title_id, row["season"]),
        })
    seasons.sort(key=lambda s: s["number"])

    return {
        "version": VERSION,
        "built_at": now(),
        "id": title_id,
        "kind": title["kind"],
        "title": {"ru": title["title_ru"], "original": title["title_original"]},
        "year": title["year"],
        "ids": ids,
        "artwork": artwork,
        "ratings": ratings,
        "synopsis": _rows(conn, "SELECT source, lang, variant, text FROM synopsis"
                                " WHERE title_id=?", title_id),
        "genres": _rows(conn, "SELECT source, name FROM genre WHERE title_id=?", title_id),
        "countries": _rows(conn, "SELECT source, name FROM country WHERE title_id=?", title_id),
        "credits": _rows(conn, "SELECT c.department, c.character, c.ord, c.episode_count,"
                               " c.source, p.name_ru, p.name_en, p.photo"
                               " FROM title_credit c JOIN person p ON p.id=c.person_id"
                               " WHERE c.title_id=? ORDER BY c.ord IS NULL, c.ord", title_id),
        "seasons": seasons,
        "trailers": _rows(conn, "SELECT source, source_key, kind, name, lang, official, url"
                                " FROM trailer WHERE title_id=?", title_id),
        "awards": _rows(conn, "SELECT source, name, nomination, year, won FROM award"
                              " WHERE title_id=?", title_id),
        "badges": _rows(conn, "SELECT source, type, start_at, finish_at FROM badge"
                              " WHERE title_id=?", title_id),
        "copies": [
            dict(row, segments=_rows(
                conn, "SELECT source_key, kind, start_s, end_s FROM copy_segment"
                      " WHERE copy_id=?", row["id"]))
            for row in _rows(conn, "SELECT id, platform, platform_key, url, seasons"
                                   " FROM title_copy WHERE title_id=?", title_id)
        ],
    }


def by_kinopub(conn, kinopub_id) -> dict | None:
    row = conn.execute(
        "SELECT title_id FROM title_external_id WHERE namespace='kinopub' AND value=?",
        (str(kinopub_id),)).fetchone()
    return build(conn, row["title_id"]) if row else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("kinopub_id", nargs="?")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--export", type=Path, help="write every document as a file")
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()

    conn = connect(args.db)

    if args.export:
        args.export.mkdir(parents=True, exist_ok=True)
        query = ("SELECT value FROM title_external_id WHERE namespace='kinopub'"
                 " ORDER BY CAST(value AS INTEGER)")
        if args.limit:
            query += f" LIMIT {int(args.limit)}"
        written = total = 0
        for row in conn.execute(query):
            document = by_kinopub(conn, row["value"])
            if not document:
                continue
            # Shard by the last two digits so no directory holds 53 000 files.
            shard = args.export / f"{int(row['value']) % 100:02d}"
            shard.mkdir(exist_ok=True)
            payload = json.dumps(document, ensure_ascii=False, separators=(",", ":"))
            (shard / f"{row['value']}.json").write_text(payload)
            written += 1
            total += len(payload)
        print(f"{written:,} documents · {total / 1e6:.1f} MB · mean "
              f"{total / max(written, 1) / 1024:.1f} KB")
        return 0

    if not args.kinopub_id:
        parser.error("give a kino.pub id, or --export")
    document = by_kinopub(conn, args.kinopub_id)
    if not document:
        print(f"no title for kino.pub id {args.kinopub_id}")
        return 1
    print(json.dumps(document, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
