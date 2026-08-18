"""One importer per source. Each reads a dump, stores raw, then derives.

Adding a source means adding a function here and one line in ingest.py. Nothing
else in the pipeline knows a source exists.
"""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path

from common import (Run, add_image, add_rating, add_rows, enrich_title, find_by_external,
                    link_external, now, resolve_person, resolve_title, store_raw,
                    upsert_copy)

TOOLS = Path(__file__).resolve().parent.parent

KINOPUB_DB = TOOLS / "kinopub-snapshot" / "data" / "snapshot.db"
KINOPOISK_DB = TOOLS / "kinopoisk-metadata" / "data" / "kinopoisk.db"
TVOE_DIR = TOOLS / "tvoe_data"

# kino.pub's `type` collapses to two shapes; the original value is kept on the
# raw payload, so nothing is lost by simplifying here.
SERIES_TYPES = {"serial", "docuserial", "tvshow"}

# kino.pub artwork is addressable by id at a fixed set of sizes — the property
# the whole predictable-image-URL plan depends on.
KINOPUB_POSTER = "https://m.staticpop.net/poster/item/{size}/{id}.jpg"
KINOPUB_SIZES = ("small", "medium", "big", "wide")


def _json_list(value):
    if not value:
        return []
    try:
        parsed = json.loads(value)
        return parsed if isinstance(parsed, list) else [parsed]
    except (json.JSONDecodeError, TypeError):
        return [part.strip() for part in str(value).split(",") if part.strip()]


# --------------------------------------------------------------- kino.pub

def ingest_kinopub(conn, *, limit=None):
    """53k titles: the spine. Every other source attaches to what this creates."""
    run = Run(conn, "kinopub")
    if not KINOPUB_DB.exists():
        run.finish(note="snapshot.db missing")
        return run

    source_db = sqlite3.connect(KINOPUB_DB)
    source_db.row_factory = sqlite3.Row
    query = "SELECT * FROM items" + (f" LIMIT {int(limit)}" if limit else "")

    for row in source_db.execute(query):
        item = dict(row)
        store_raw(conn, "kinopub", "item", item["id"], item)
        run.raw += 1

        kind = "series" if item["type"] in SERIES_TYPES else "movie"
        title_id, method = resolve_title(
            conn,
            ids={"kinopub": item["id"], "imdb": item["imdb_id"], "kinopoisk": item["kinopoisk_id"]},
            kind=kind,
            title_ru=item["title_ru"] or item["title"],
            title_original=item["title_original"],
            year=item["year"],
            # The spine is authoritative: never fuzzy-match kino.pub rows onto
            # each other, or two remakes collapse into one title.
            allow_title_match=False,
        )
        run.count(method)
        enrich_title(conn, title_id, kind=kind, title_ru=item["title_ru"] or item["title"],
                     title_original=item["title_original"], year=item["year"])

        link_external(conn, title_id, "kinopub", item["id"], "dump")
        if item["imdb_id"]:
            link_external(conn, title_id, "imdb", f"tt{int(item['imdb_id']):07d}", "dump")
        link_external(conn, title_id, "kinopoisk", item["kinopoisk_id"], "dump")

        add_rating(conn, title_id, "imdb", item["imdb_rating"], item["imdb_votes"])
        add_rating(conn, title_id, "kinopoisk", item["kinopoisk_rating"], item["kinopoisk_votes"])
        # kino.pub reports a like percentage, not a 10-point score.
        add_rating(conn, title_id, "kinopub", item["kinopub_rating_percentage"],
                   item["kinopub_rating_votes"], scale=100.0)

        for size in KINOPUB_SIZES:
            add_image(conn, title_id, "poster" if size != "wide" else "backdrop",
                      "kinopub", KINOPUB_POSTER.format(size=size, id=item["id"]))

        add_rows(conn, "country", ("title_id", "source", "name"),
                 [(title_id, "kinopub", c) for c in _json_list(item["countries"])])

        # kino.pub is a platform as well as a source: this row is its copy, and
        # is where its streams, qualities and audio tracks will hang once we
        # read them. `title` stays a fact about the work.
        upsert_copy(conn, title_id, "kinopub", item["id"])

    source_db.close()
    run.finish()
    return run


# ------------------------------------------------------------------- tvoe

def ingest_tvoe(conn):
    """4.3k curated Russian titles: clean backdrops, RU logos, skip markers.

    No external ids at all — matching is by original title + year, which is why
    `resolve_title` records the method it used.
    """
    run = Run(conn, "tvoe")
    files = [("films", TVOE_DIR / "catalog_films_detailed.json"),
             ("serials", TVOE_DIR / "catalog_serials_detailed.json")]

    for category, path in files:
        if not path.exists():
            continue
        for item in json.loads(path.read_text()):
            store_raw(conn, "tvoe", f"{category}_detailed", item["_id"], item)
            run.raw += 1

            year = None
            if item.get("dateReleased"):
                try:
                    year = int(str(item["dateReleased"])[:4])
                except ValueError:
                    year = None

            title_id, method = resolve_title(
                conn,
                ids={"tvoe": item["_id"]},
                kind="series" if category == "serials" else "movie",
                title_ru=item.get("name"),
                title_original=item.get("origName"),
                year=year,
            )
            run.count(method)
            link_external(conn, title_id, "tvoe", item["_id"],
                          method if method.startswith("title_year") else "dump",
                          confidence=0.8 if method.startswith("title_year") else 1.0)
            enrich_title(conn, title_id, title_ru=item.get("name"),
                         title_original=item.get("origName"), year=year)

            add_rating(conn, title_id, "tvoe", item.get("rating"), None)

            # cdnUrl is the original and its URL does not change; the sibling
            # `url` is a Next resizer with w/q params and is not durable.
            for our_kind, their_kind in (("poster", "poster"), ("backdrop", "cover"),
                                         ("logo", "logo")):
                asset = (item.get("images") or {}).get(their_kind) or {}
                add_image(conn, title_id, our_kind, "tvoe", asset.get("cdnUrl"),
                          stable=True, lang="ru")

            for text_field, variant in (("description", "full"), ("shortDesc", "short")):
                if item.get(text_field):
                    conn.execute(
                        "INSERT OR IGNORE INTO synopsis(title_id,source,lang,variant,text)"
                        " VALUES (?,?,'ru',?,?)", (title_id, "tvoe", variant, item[text_field]),
                    )

            add_rows(conn, "genre", ("title_id", "source", "name"),
                     [(title_id, "tvoe", g) for g in item.get("genres") or []])
            add_rows(conn, "country", ("title_id", "source", "name"),
                     [(title_id, "tvoe", c) for c in item.get("countries") or []])

            badge = item.get("badge") or {}
            if badge.get("type"):
                conn.execute(
                    "INSERT OR IGNORE INTO badge(title_id,source,type,start_at,finish_at)"
                    " VALUES (?,?,?,?,?)",
                    (title_id, "tvoe", badge["type"], badge.get("startAt"), badge.get("finishAt")),
                )

            for order, entry in enumerate(item.get("persons") or []):
                if not entry.get("name"):
                    continue
                person_id = resolve_person(conn, name_ru=entry["name"])
                conn.execute(
                    "INSERT OR IGNORE INTO title_credit"
                    "(title_id,person_id,department,character,ord,episode_count,source)"
                    " VALUES (?,?,?,NULL,?,NULL,'tvoe')",
                    (title_id, person_id, entry.get("type"), order),
                )

            _tvoe_copy(conn, title_id, item)

    run.finish()
    return run


def _tvoe_copy(conn, title_id, item):
    """tvoe's *copy* — its streams, encodes, tracks and markers.

    None of this transfers to kino.pub's file. Different encode, different dub
    tracks, different intro offsets. It hangs off `title_copy`, never `title`.
    """
    copy_id = upsert_copy(conn, title_id, "tvoe", item["_id"],
                          url=item.get("url"), seasons=item.get("seasonsCount"))

    videos = item.get("videos") or {}
    batches = [("feature", None, videos.get("films") or [])]
    for season_index, season in enumerate(videos.get("seasons") or [], start=1):
        batches.append(("episode", season_index, season or []))

    for kind, season, entries in batches:
        for episode_index, video in enumerate(entries, start=1):
            if not video.get("_id"):
                continue
            conn.execute(
                "INSERT OR IGNORE INTO copy_video(copy_id,source_key,kind,season,episode,"
                "name,duration,url,thumbnail,qualities,audio,subtitles)"
                " VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                (copy_id, video["_id"], kind, season,
                 episode_index if season else None,
                 video.get("nameForUser"), video.get("duration"),
                 video.get("hlsUrl") or video.get("src"), video.get("thumbnail"),
                 json.dumps(video.get("qualities") or [], ensure_ascii=False),
                 json.dumps(video.get("audio") or [], ensure_ascii=False),
                 json.dumps(video.get("subtitles") or [], ensure_ascii=False)),
            )
            for segment, start_key, end_key in (("preview", "previewStartTime", "previewEndTime"),
                                                ("credits", "creditsStartTime", "creditsEndTime"),
                                                ("replay", "replayStartTime", "replayEndTime")):
                if video.get(start_key) is None and video.get(end_key) is None:
                    continue
                conn.execute(
                    "INSERT OR IGNORE INTO copy_segment(copy_id,source_key,kind,start_s,end_s)"
                    " VALUES (?,?,?,?,?)",
                    (copy_id, video["_id"], segment, video.get(start_key), video.get(end_key)),
                )

    # A trailer is about the work, not the copy — it plays the same anywhere.
    for video in videos.get("trailers") or []:
        if video.get("_id"):
            conn.execute(
                "INSERT OR IGNORE INTO trailer(title_id,source,source_key,kind,name,lang,"
                "official,url) VALUES (?,'tvoe',?,'trailer',?,'ru',NULL,?)",
                (title_id, video["_id"], video.get("nameForUser"),
                 video.get("hlsUrl") or video.get("src")),
            )


# -------------------------------------------------------------- kinopoisk

def ingest_kinopoisk(conn):
    """2.3k detailed films plus 40k episodes, 7.8k awards, staff with RU+EN names.

    The RU↔EN name pairs here are exact, on one row — the cheapest cross-alphabet
    bridge we have, and the reason this source earns its quota.
    """
    run = Run(conn, "kinopoisk")
    if not KINOPOISK_DB.exists():
        run.finish(note="kinopoisk.db missing")
        return run

    source_db = sqlite3.connect(KINOPOISK_DB)
    source_db.row_factory = sqlite3.Row
    title_ids: dict[int, int] = {}

    for row in source_db.execute("SELECT * FROM kp_films"):
        film = dict(row)
        kp_id = film["kinopoisk_id"]
        store_raw(conn, "kinopoisk", "film", kp_id, film)
        run.raw += 1

        title_id, method = resolve_title(
            conn,
            ids={"kinopoisk": kp_id, "imdb": film["imdb_id"]},
            kind="series" if film["serial"] else "movie",
            title_ru=film["name_ru"],
            title_original=film["name_original"] or film["name_en"],
            year=film["year"],
        )
        run.count(method)
        title_ids[kp_id] = title_id
        link_external(conn, title_id, "kinopoisk", kp_id, "dump")
        link_external(conn, title_id, "imdb", film["imdb_id"], "dump")
        enrich_title(conn, title_id, title_ru=film["name_ru"],
                     title_original=film["name_original"] or film["name_en"], year=film["year"])

        for source, value_column, votes_column in (
            ("kinopoisk", "rating_kinopoisk", "rating_kinopoisk_vote_count"),
            ("imdb", "rating_imdb", "rating_imdb_vote_count"),
            ("film_critics", "rating_film_critics", "rating_film_critics_vote_count"),
            ("rf_critics", "rating_rf_critics", "rating_rf_critics_vote_count"),
            ("await", "rating_await", "rating_await_count"),
            ("good_review", "rating_good_review", "rating_good_review_vote_count"),
        ):
            add_rating(conn, title_id, source, film[value_column], film[votes_column])

        add_image(conn, title_id, "poster", "kinopoisk", film["poster_url"])
        add_image(conn, title_id, "backdrop", "kinopoisk", film["cover_url"])
        add_image(conn, title_id, "logo", "kinopoisk", film["logo_url"], lang="ru")

        for text_field, variant in (("description", "full"), ("short_description", "short"),
                                    ("slogan", "tagline")):
            if film[text_field]:
                conn.execute(
                    "INSERT OR IGNORE INTO synopsis(title_id,source,lang,variant,text)"
                    " VALUES (?,'kinopoisk','ru',?,?)", (title_id, variant, film[text_field]),
                )

    def title_of(kp_id):
        return title_ids.get(kp_id)

    for table, columns, target in (
        ("kp_film_genres", ("kinopoisk_id", "genre"), "genre"),
        ("kp_film_countries", ("kinopoisk_id", "country"), "country"),
    ):
        rows = []
        for row in source_db.execute(f"SELECT * FROM {table}"):
            title_id = title_of(row[columns[0]])
            if title_id:
                rows.append((title_id, "kinopoisk", row[columns[1]]))
        add_rows(conn, target, ("title_id", "source", "name"), rows)

    for row in source_db.execute("SELECT * FROM kp_staff"):
        title_id = title_of(row["kinopoisk_id"])
        if not title_id:
            continue
        person_id = resolve_person(
            conn, name_ru=row["name_ru"], name_en=row["name_en"],
            ids={"kinopoisk_staff": row["staff_id"]},
        )
        conn.execute(
            "INSERT OR IGNORE INTO person_external_id(person_id,namespace,value)"
            " VALUES (?,'kinopoisk_staff',?)", (person_id, str(row["staff_id"])),
        )
        conn.execute(
            "INSERT OR IGNORE INTO title_credit"
            "(title_id,person_id,department,character,ord,episode_count,source)"
            " VALUES (?,?,?,?,NULL,NULL,'kinopoisk')",
            (title_id, person_id, (row["profession_key"] or "").lower() or None,
             row["character_name"]),
        )

    episodes, awards, images, facts = [], [], [], []
    for row in source_db.execute("SELECT * FROM kp_episodes"):
        title_id = title_of(row["kinopoisk_id"])
        if title_id:
            episodes.append((title_id, row["season_number"], row["episode_number"],
                             row["name_ru"], row["name_en"], row["synopsis"],
                             row["release_date"], "kinopoisk"))
    for row in source_db.execute("SELECT * FROM kp_awards"):
        title_id = title_of(row["kinopoisk_id"])
        if title_id:
            awards.append((title_id, "kinopoisk", row["name"], row["nomination_name"],
                           row["year"], 1 if row["win"] else 0))
    for row in source_db.execute("SELECT * FROM kp_images"):
        title_id = title_of(row["kinopoisk_id"])
        if title_id:
            images.append((title_id, "still", "kinopoisk", row["image_url"], 1, None))
    try:
        for row in source_db.execute("SELECT * FROM kp_person_facts"):
            pass  # person-level facts belong to the person page, not the title
    except sqlite3.OperationalError:
        pass

    add_rows(conn, "episode", ("title_id", "season", "number", "name_ru", "name_en",
                               "synopsis", "air_date", "source"), episodes)
    add_rows(conn, "award", ("title_id", "source", "name", "nomination", "year", "won"), awards)
    add_rows(conn, "image", ("title_id", "kind", "source", "url", "stable", "lang"), images)

    source_db.close()
    run.finish()
    return run


# ------------------------------------------------------- replay from raw

def replay_tmdb(conn):
    """Re-derive TMDB from stored payloads. No network, no quota.

    This is the path whose absence made `--fresh` destructive: the payloads were
    already on disk, and nothing could read them back.
    """
    import fetch_tmdb

    run = Run(conn, "tmdb:replay")
    for row in conn.execute(
        "SELECT kind, source_key, body FROM raw_payload WHERE source='tmdb'"
    ).fetchall():
        payload = json.loads(row["body"])
        imdb = (payload.get("external_ids") or {}).get("imdb_id") or payload.get("imdb_id")
        title_id = find_by_external(conn, "imdb", imdb) if imdb else None
        if not title_id:
            continue
        fetch_tmdb.derive(conn, title_id, int(row["source_key"]), row["kind"], payload)
        run.raw += 1
        run.seen += 1
    run.finish()
    return run


def replay_omdb(conn):
    """Same, for OMDb. Its raw is keyed by the IMDb id we asked with."""
    import fetch_omdb

    run = Run(conn, "omdb:replay")
    for row in conn.execute(
        "SELECT source_key, body FROM raw_payload WHERE source='omdb'"
    ).fetchall():
        title_id = find_by_external(conn, "imdb", row["source_key"])
        if not title_id:
            continue
        fetch_omdb.derive(conn, title_id, json.loads(row["body"]))
        run.raw += 1
        run.seen += 1
    run.finish()
    return run


def replay_kinopoisk_proxy(conn):
    """Same, for the keyless proxy. Its raw is keyed by the Kinopoisk id we
    asked with, one row per resource (facts/reviews/staff/images)."""
    import fetch_kinopoisk_proxy

    run = Run(conn, "kinopoisk_proxy:replay")
    for row in conn.execute(
        "SELECT kind, source_key, body FROM raw_payload WHERE source='kinopoisk_proxy'"
    ).fetchall():
        title_id = find_by_external(conn, "kinopoisk", row["source_key"])
        if not title_id:
            continue
        fetch_kinopoisk_proxy.derive(conn, title_id, row["kind"], json.loads(row["body"]))
        run.raw += 1
        run.seen += 1
    run.finish()
    return run
