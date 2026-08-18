#!/usr/bin/env python3
"""Facts, reviews, full crew-with-characters, and stills. No key, ever.

    python3 fetch_kinopoisk_proxy.py --titles 41,905
    python3 fetch_kinopoisk_proxy.py --limit 300

`kpapp.link/kpapi/films/<kinopoiskId>/{facts,reviews,staff,images}` — the same
keyless proxy the community client already uses for these four things (see
`docs/providers/kinopoisk-proxy.md`). No auth, no header, no documented quota:
someone else's server, best-effort, every field optional.

This is the cheap tier and the one meant to refresh often — nothing here spends
anyone's quota, so there is no reason to fetch it once and never again. It is
not a substitute for the keyed API's `/films/{id}` and `/films/{id}/awards`,
which this proxy does not expose at all; those stay on the offline dump /
`bulk_films.py`, run lazily, backbone-style, when a personal key is supplied.

`staff` is the primary win here beyond facts/reviews: it is full crew, not just
cast, and it carries each actor's character and (sometimes) a Kinopoisk-hosted
headshot — most of which currently has nowhere to come from, since only 135 of
38 547 people in the record have a photo at all.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import DEFAULT_DB, add_rows, connect, now, resolve_person, store_raw  # noqa: E402

BASE = "https://kpapp.link/kpapi/films"
AGENT = "kinopub-metadata-ingest/1.0 (+tools/metadata-ingest)"
RESOURCES = ("facts", "reviews", "staff", "images")

# A poster URL with no actual photo behind it — filtered the same way the
# client's `nonPlaceholderImageURL` does.
PLACEHOLDER_MARKERS = ("shared/no-photo", "placeholder")


def get(kinopoisk_id, resource, *, timeout=15):
    url = f"{BASE}/{kinopoisk_id}/{resource}"
    request = urllib.request.Request(url, headers={"Accept": "application/json",
                                                    "User-Agent": AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read().decode("utf-8"), strict=False)
    except urllib.error.HTTPError as error:
        return error.code, None
    except Exception:
        return None, None


def is_real_photo(url: str | None) -> bool:
    return bool(url) and not any(marker in url for marker in PLACEHOLDER_MARKERS)


def derive(conn, title_id, resource, payload):
    if resource == "facts":
        rows = [(title_id, "kinopoisk_proxy", item["text"], 1 if item.get("spoiler") else 0)
                for item in payload.get("items") or [] if item.get("text")]
        add_rows(conn, "fact", ("title_id", "source", "text", "spoiler"), rows)

    elif resource == "reviews":
        rows = []
        for item in payload.get("items") or []:
            key = item.get("kinopoiskId")
            if key is None:
                continue
            rows.append((title_id, "kinopoisk_proxy", str(key), item.get("type"),
                        item.get("author"), item.get("title"), item.get("description"),
                        item.get("date")))
        add_rows(conn, "review", ("title_id", "source", "source_key", "kind", "author",
                                  "headline", "body", "date"), rows)

    elif resource == "staff":
        for order, member in enumerate(payload if isinstance(payload, list) else []):
            name_ru = (member.get("nameRu") or "").strip()
            name_en = (member.get("nameEn") or "").strip()
            if not name_ru and not name_en:
                continue
            person_id = resolve_person(conn, name_ru=name_ru or None, name_en=name_en or None,
                                       ids={"kinopoisk_staff": member.get("staffId")})
            if member.get("staffId") is not None:
                conn.execute(
                    "INSERT OR IGNORE INTO person_external_id(person_id,namespace,value)"
                    " VALUES (?,'kinopoisk_staff',?)", (person_id, str(member["staffId"])),
                )
            if is_real_photo(member.get("posterUrl")):
                conn.execute("UPDATE person SET photo=?, photo_source='kinopoisk_proxy'"
                            " WHERE id=? AND photo IS NULL",
                            (member["posterUrl"], person_id))
            department = (member.get("professionKey") or "").lower() or None
            character = member.get("description") if department == "actor" else None
            conn.execute(
                "INSERT OR IGNORE INTO title_credit"
                "(title_id,person_id,department,character,ord,episode_count,source)"
                " VALUES (?,?,?,?,?,NULL,'kinopoisk_proxy')",
                (title_id, person_id, department, character, order),
            )

    elif resource == "images":
        rows = [(title_id, "still", "kinopoisk_proxy", item["imageUrl"], 1, None)
                for item in payload.get("items") or [] if item.get("imageUrl")]
        add_rows(conn, "image", ("title_id", "kind", "source", "url", "stable", "lang"), rows)


def pending(conn, *, limit=None, titles=None, refresh=False):
    asked = "" if refresh else (
        " AND NOT EXISTS (SELECT 1 FROM fetch_log f WHERE f.source='kinopoisk_proxy'"
        " AND f.endpoint='staff' AND f.key=e.value)")
    chosen = f" AND e.title_id IN ({','.join(str(int(v)) for v in titles)})" if titles else ""
    query = ("SELECT e.title_id, e.value AS kinopoisk_id,"
            " (SELECT votes FROM rating r WHERE r.title_id=e.title_id AND r.source='kinopoisk')"
            " AS votes FROM title_external_id e"
            f" WHERE e.namespace='kinopoisk'{asked}{chosen}"
            " ORDER BY votes IS NULL, votes DESC")
    if limit:
        query += f" LIMIT {int(limit)}"
    return conn.execute(query).fetchall()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--titles")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--rps", type=float, default=3.0, help="be polite — this is someone else's server")
    args = parser.parse_args()

    titles = [part for part in (args.titles or "").split(",") if part.strip()]
    if not titles and not args.limit:
        parser.error("say what to fetch: --titles or --limit")

    conn = connect(args.db)
    queue = pending(conn, limit=args.limit, titles=titles, refresh=args.refresh)
    if not queue:
        print("nothing pending")
        return 0

    print(f"{len(queue):,} titles · no key needed · {args.rps} rps")
    interval = 1.0 / args.rps if args.rps else 0.0
    ok = fail = 0

    for index, row in enumerate(queue, start=1):
        any_ok = False
        for resource in RESOURCES:
            status, payload = get(row["kinopoisk_id"], resource)
            if payload is None:
                continue
            store_raw(conn, "kinopoisk_proxy", resource, row["kinopoisk_id"], payload,
                     via="fetch")
            derive(conn, row["title_id"], resource, payload)
            any_ok = True
            conn.execute(
                "INSERT OR REPLACE INTO fetch_log(source,endpoint,key,status,fetched_at,"
                "ttl_seconds,note) VALUES ('kinopoisk_proxy',?,?,?,?,?,NULL)",
                (resource, row["kinopoisk_id"], status, now(), 60 * 60 * 24 * 14),
            )
            if interval:
                time.sleep(interval)
        ok += 1 if any_ok else 0
        fail += 0 if any_ok else 1
        if index % 100 == 0:
            conn.commit()
            print(f"  {index:,}/{len(queue):,}  ok={ok:,} fail={fail:,}")

    conn.commit()
    print(f"\nok={ok:,}  fail={fail:,}")
    for label, query in (
        ("facts", "SELECT count(*) FROM fact WHERE source='kinopoisk_proxy'"),
        ("reviews", "SELECT count(*) FROM review WHERE source='kinopoisk_proxy'"),
        ("stills", "SELECT count(*) FROM image WHERE source='kinopoisk_proxy'"),
        ("crew credits", "SELECT count(*) FROM title_credit WHERE source='kinopoisk_proxy'"),
        ("photos from kinopoisk staff",
         "SELECT count(*) FROM person WHERE photo_source='kinopoisk_proxy'"),
    ):
        print(f"  {label:<28} {conn.execute(query).fetchone()[0]:>8,}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
