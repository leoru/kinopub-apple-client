#!/usr/bin/env python3
"""Fill the record from TMDB, through our worker proxy. Resumable, rate-limited.

    python3 fetch_tmdb.py --limit 200        # a taste
    python3 fetch_tmdb.py                    # everything unresolved, popular first
    python3 fetch_tmdb.py --refresh          # re-fetch titles we already have

No API token lives here: the worker holds it. Progress is in `fetch_log`, so a
killed run resumes where it stopped and never re-asks a question it already has
an answer to — including a negative one.

Uses the full append budget (12–13 of the 20 slots) rather than the 6 the app
sends today, so one HTTP request per title yields credits, every artwork
variant, videos, keywords with ids, external ids, watch providers, reviews,
recommendations, translations and — for series — episode groups.
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import (DEFAULT_DB, add_image, add_rating, add_rows, connect,  # noqa: E402
                    link_external, now, resolve_person, store_raw)

PROXY = "https://kinopub-tmdb-proxy.traneblow1nd.workers.dev"

MOVIE_APPEND = ("credits,images,videos,external_ids,keywords,release_dates,translations,"
                "alternative_titles,watch/providers,recommendations,similar,reviews")
TV_APPEND = ("aggregate_credits,images,videos,external_ids,content_ratings,keywords,"
             "translations,alternative_titles,watch/providers,recommendations,similar,"
             "reviews,episode_groups")

IMAGE_BASE = "https://image.tmdb.org/t/p/original"


class Throttle:
    """Simple shared rate limit — the worker edge-caches, TMDB does not need abuse."""

    def __init__(self, rps: float):
        self.interval = 1.0 / rps if rps > 0 else 0.0
        self.lock = threading.Lock()
        self.next_at = 0.0

    def wait(self):
        if not self.interval:
            return
        with self.lock:
            delay = max(0.0, self.next_at - time.monotonic())
            self.next_at = max(self.next_at, time.monotonic()) + self.interval
        if delay:
            time.sleep(delay)


def get(path, params, throttle, *, timeout=20):
    throttle.wait()
    url = f"{PROXY}{path}?{urllib.parse.urlencode(params)}"
    # Cloudflare answers the default `Python-urllib/x.y` agent with a 403, which
    # reads as "no match" everywhere downstream. Identify ourselves properly.
    request = urllib.request.Request(url, headers={
        "Accept": "application/json",
        "User-Agent": "kinopub-metadata-ingest/1.0 (+tools/metadata-ingest)",
    })
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read().decode("utf-8"), strict=False)
    except urllib.error.HTTPError as error:
        return error.code, None
    except Exception:  # network blip — transient, do not record as an answer
        return None, None


# ------------------------------------------------------------------ derive

def derive(conn, title_id, tmdb_id, media_type, payload):
    is_tv = media_type == "tv"
    link_external(conn, title_id, "tmdb", f"{media_type}/{tmdb_id}", "find:imdb")

    external = payload.get("external_ids") or {}
    for namespace, key in (("wikidata", "wikidata_id"), ("tvdb", "tvdb_id"), ("imdb", "imdb_id")):
        link_external(conn, title_id, namespace, external.get(key), "tmdb:external_ids")

    add_rating(conn, title_id, "tmdb", payload.get("vote_average"), payload.get("vote_count"))

    # Every artwork variant with its dimensions and community votes, so "best
    # poster" can be an argued choice later instead of whoever answered first.
    images = payload.get("images") or {}
    for our_kind, their_kind in (("poster", "posters"), ("backdrop", "backdrops"),
                                 ("logo", "logos")):
        for asset in images.get(their_kind) or []:
            if not asset.get("file_path"):
                continue
            conn.execute(
                "INSERT OR IGNORE INTO image(title_id,kind,source,url,stable,lang,width,height)"
                " VALUES (?,?,'tmdb',?,1,?,?,?)",
                (title_id, our_kind, IMAGE_BASE + asset["file_path"],
                 asset.get("iso_639_1"), asset.get("width"), asset.get("height")),
            )
    for our_kind, key in (("poster", "poster_path"), ("backdrop", "backdrop_path")):
        if payload.get(key):
            add_image(conn, title_id, our_kind, "tmdb", IMAGE_BASE + payload[key])

    for variant, key in (("full", "overview"), ("tagline", "tagline")):
        if payload.get(key):
            conn.execute(
                "INSERT OR IGNORE INTO synopsis(title_id,source,lang,variant,text)"
                " VALUES (?,'tmdb',?,?,?)",
                (title_id, (payload.get("_lang") or "en")[:2], variant, payload[key]),
            )

    add_rows(conn, "genre", ("title_id", "source", "name"),
             [(title_id, "tmdb", g["name"]) for g in payload.get("genres") or [] if g.get("name")])
    add_rows(conn, "country", ("title_id", "source", "name"),
             [(title_id, "tmdb", c["name"]) for c in payload.get("production_countries") or []
              if c.get("name")])

    # Keyword *ids*, not just names — similarity needs the id.
    keywords = payload.get("keywords") or {}
    for keyword in keywords.get("keywords") or keywords.get("results") or []:
        if keyword.get("name"):
            conn.execute(
                "INSERT OR IGNORE INTO genre(title_id,source,name) VALUES (?,'tmdb:keyword',?)",
                (title_id, f"{keyword['id']}:{keyword['name']}"),
            )

    credits = payload.get("aggregate_credits") if is_tv else payload.get("credits")
    credits = credits or payload.get("credits") or {}
    for person in (credits.get("cast") or [])[:60]:
        if not person.get("name"):
            continue
        roles = person.get("roles") or []
        character = roles[0].get("character") if roles else person.get("character")
        episodes = person.get("total_episode_count") or (
            roles[0].get("episode_count") if roles else None)
        person_id = resolve_person(conn, name_en=person["name"], ids={"tmdb": person.get("id")})
        conn.execute(
            "INSERT OR IGNORE INTO person_external_id(person_id,namespace,value)"
            " VALUES (?,'tmdb',?)", (person_id, str(person.get("id"))),
        )
        if person.get("profile_path"):
            conn.execute("UPDATE person SET photo=COALESCE(photo,?) WHERE id=?",
                         (IMAGE_BASE + person["profile_path"], person_id))
        conn.execute(
            "INSERT OR IGNORE INTO title_credit"
            "(title_id,person_id,department,character,ord,episode_count,source)"
            " VALUES (?,?,'actor',?,?,?,'tmdb')",
            (title_id, person_id, character, person.get("order"), episodes),
        )
    for person in (credits.get("crew") or [])[:60]:
        if not person.get("name"):
            continue
        jobs = person.get("jobs") or []
        job = (jobs[0].get("job") if jobs else person.get("job")) or person.get("department")
        person_id = resolve_person(conn, name_en=person["name"], ids={"tmdb": person.get("id")})
        conn.execute(
            "INSERT OR IGNORE INTO title_credit"
            "(title_id,person_id,department,character,ord,episode_count,source)"
            " VALUES (?,?,?,NULL,NULL,NULL,'tmdb')",
            (title_id, person_id, (job or "crew").lower()),
        )

    for video in (payload.get("videos") or {}).get("results") or []:
        if not video.get("key"):
            continue
        conn.execute(
            "INSERT OR IGNORE INTO video(title_id,source,source_key,kind,name,url,qualities,"
            "audio,subtitles) VALUES (?,'tmdb',?,?,?,?,'[]','[]','[]')",
            (title_id, video["key"], (video.get("type") or "trailer").lower(),
             video.get("name"),
             f"https://www.youtube.com/watch?v={video['key']}"
             if video.get("site") == "YouTube" else None),
        )

    # Availability, already in the payload we paid for.
    providers = (payload.get("watch/providers") or {}).get("results") or {}
    for region, entry in providers.items():
        for offer_kind in ("flatrate", "rent", "buy", "free", "ads"):
            for provider in entry.get(offer_kind) or []:
                conn.execute(
                    "INSERT OR IGNORE INTO badge(title_id,source,type,start_at,finish_at)"
                    " VALUES (?,?,?,NULL,NULL)",
                    (title_id, f"tmdb:watch:{region}",
                     f"{offer_kind}:{provider.get('provider_name')}"),
                )

    if is_tv:
        for season in payload.get("seasons") or []:
            if season.get("season_number") is None:
                continue
            add_rating(conn, title_id, "tmdb", season.get("vote_average"), None,
                       season=season["season_number"])
        for key in ("last_episode_to_air", "next_episode_to_air"):
            episode = payload.get(key)
            if episode and episode.get("season_number") is not None:
                add_rows(conn, "episode",
                         ("title_id", "season", "number", "name_en", "synopsis", "air_date",
                          "source"),
                         [(title_id, episode["season_number"], episode.get("episode_number"),
                           episode.get("name"), episode.get("overview"),
                           episode.get("air_date"), "tmdb")])
                add_rating(conn, title_id, "tmdb", episode.get("vote_average"),
                           episode.get("vote_count"), season=episode["season_number"],
                           episode=episode.get("episode_number"))


# -------------------------------------------------------------------- main

def pending(conn, refresh, limit):
    """Titles with an IMDb id and no TMDB answer yet, most-voted first.

    Popularity order matters: a killed run has still covered what people open.
    """
    asked = "" if refresh else (
        " AND NOT EXISTS (SELECT 1 FROM fetch_log f WHERE f.source='tmdb'"
        " AND f.endpoint='title' AND f.key=e.value)")
    query = (
        "SELECT e.title_id, e.value AS imdb, t.kind,"
        " (SELECT votes FROM rating r WHERE r.title_id=e.title_id AND r.source='imdb') AS votes"
        " FROM title_external_id e JOIN title t ON t.id=e.title_id"
        f" WHERE e.namespace='imdb'{asked}"
        " ORDER BY votes IS NULL, votes DESC"
    )
    if limit:
        query += f" LIMIT {int(limit)}"
    return conn.execute(query).fetchall()


def fetch_one(row, language, throttle):
    """Network only — no database touched, so this is safe on a worker thread."""
    status, found = get(f"/3/find/{row['imdb']}",
                        {"external_source": "imdb_id", "language": language}, throttle)
    if found is None:
        return row, None, None, status

    for media_type in ("tv", "movie") if row["kind"] == "series" else ("movie", "tv"):
        results = found.get(f"{media_type}_results") or []
        if not results:
            continue
        tmdb_id = results[0]["id"]
        status, payload = get(
            f"/3/{media_type}/{tmdb_id}",
            {"language": language,
             "append_to_response": TV_APPEND if media_type == "tv" else MOVIE_APPEND,
             "include_image_language": "ru,en,null"},
            throttle)
        if payload:
            payload["_lang"] = language
            return row, (tmdb_id, media_type), payload, status
        return row, None, None, status
    return row, None, None, 404


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--language", default="ru-RU")
    parser.add_argument("--rps", type=float, default=12.0)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    conn = connect(args.db)
    queue = pending(conn, args.refresh, args.limit)
    if not queue:
        print("nothing pending — the record already has an answer for every IMDb id")
        return 0

    print(f"{len(queue):,} titles · {args.language} · {args.rps} rps · {args.workers} workers")
    throttle = Throttle(args.rps)
    resolved = missed = failed = 0
    started = time.monotonic()

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(fetch_one, row, args.language, throttle) for row in queue]
        for index, future in enumerate(futures, start=1):
            row, identity, payload, status = future.result()
            if identity and payload:
                tmdb_id, media_type = identity
                store_raw(conn, "tmdb", media_type, tmdb_id, payload, via="fetch")
                derive(conn, row["title_id"], tmdb_id, media_type, payload)
                resolved += 1
            elif status is None:
                failed += 1
            else:
                missed += 1
            # A miss is an answer and gets logged; a network failure is not.
            if status is not None:
                conn.execute(
                    "INSERT OR REPLACE INTO fetch_log(source,endpoint,key,status,fetched_at,"
                    "ttl_seconds,note) VALUES ('tmdb','title',?,?,?,?,?)",
                    (row["imdb"], status or 0, now(), 60 * 60 * 24 * 30,
                     None if identity else "no match"),
                )
            if index % 200 == 0:
                conn.commit()
                rate = index / max(0.001, time.monotonic() - started)
                print(f"  {index:,}/{len(queue):,}  resolved={resolved:,} miss={missed:,}"
                      f" fail={failed:,}  {rate:.1f}/s")

    conn.commit()
    elapsed = time.monotonic() - started
    print(f"\nresolved={resolved:,}  no-match={missed:,}  network-fail={failed:,}"
          f"  in {elapsed:.0f}s")
    for label, query in (
        ("titles with a tmdb id",
         "SELECT count(*) FROM title_external_id WHERE namespace='tmdb'"),
        ("tmdb ratings", "SELECT count(*) FROM rating WHERE source='tmdb'"),
        ("tmdb images", "SELECT count(*) FROM image WHERE source='tmdb'"),
        ("tmdb credits", "SELECT count(*) FROM title_credit WHERE source='tmdb'"),
        ("people with a tmdb id",
         "SELECT count(*) FROM person_external_id WHERE namespace='tmdb'"),
        ("trailers", "SELECT count(*) FROM video WHERE source='tmdb'"),
        ("watch-provider rows", "SELECT count(*) FROM badge WHERE source LIKE 'tmdb:watch%'"),
    ):
        print(f"  {label:<24} {conn.execute(query).fetchone()[0]:>9,}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
