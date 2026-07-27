#!/usr/bin/env python3
"""
Parses probe.db's raw JSON (already fetched by probe.py — no API calls needed
for those) into the real typed tables in schema.sql. Also fetches /images
(the one endpoint not in the original probe) fresh, one page of stills per
film, since that costs new requests.

Usage:
  python3 ingest.py --api-key <key>        # needs the key only for /images
  python3 ingest.py --skip-images          # no key needed, just re-derive tables
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
PROBE_DB = DATA_DIR / "probe.db"
OUT_DB = DATA_DIR / "kinopoisk.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"


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


def split_character(description, name_ru):
    """Actor rows carry "Actor Name — Character Name"; everything else is None."""
    if not description:
        return None
    sep = " — " if " — " in description else ("—" if "—" in description else None)
    if not sep:
        return description
    prefix, _, rest = description.partition(sep)
    if name_ru and prefix.strip() == name_ru.strip():
        return rest.strip() or None
    return description


KP_FILMS_COLUMNS = [
    "kinopoisk_id", "kinopoisk_hd_id", "imdb_id", "name_ru", "name_en", "name_original",
    "poster_url", "poster_url_preview", "cover_url", "logo_url", "reviews_count",
    "rating_good_review", "rating_good_review_vote_count", "rating_kinopoisk",
    "rating_kinopoisk_vote_count", "rating_imdb", "rating_imdb_vote_count",
    "rating_film_critics", "rating_film_critics_vote_count", "rating_await",
    "rating_await_count", "rating_rf_critics", "rating_rf_critics_vote_count",
    "web_url", "year", "film_length", "slogan", "description", "short_description",
    "editor_annotation", "is_tickets_available", "production_status", "type",
    "rating_mpaa", "rating_age_limits", "has_imax", "has_3d", "last_sync",
    "start_year", "end_year", "serial", "short_film", "completed", "fetched_at",
]


def ingest_details(conn, kp_id, body):
    d = json.loads(body)
    placeholders = ",".join("?" * len(KP_FILMS_COLUMNS))
    conn.execute(
        f"""
        INSERT INTO kp_films ({",".join(KP_FILMS_COLUMNS)})
        VALUES ({placeholders})
        ON CONFLICT(kinopoisk_id) DO UPDATE SET fetched_at=excluded.fetched_at
        """,
        (
            d["kinopoiskId"], d.get("kinopoiskHDId"), d.get("imdbId"), d.get("nameRu"),
            d.get("nameEn"), d.get("nameOriginal"), d.get("posterUrl"), d.get("posterUrlPreview"),
            d.get("coverUrl"), d.get("logoUrl"), d.get("reviewsCount"), d.get("ratingGoodReview"),
            d.get("ratingGoodReviewVoteCount"), d.get("ratingKinopoisk"), d.get("ratingKinopoiskVoteCount"),
            d.get("ratingImdb"), d.get("ratingImdbVoteCount"), d.get("ratingFilmCritics"),
            d.get("ratingFilmCriticsVoteCount"), d.get("ratingAwait"), d.get("ratingAwaitCount"),
            d.get("ratingRfCritics"), d.get("ratingRfCriticsVoteCount"), d.get("webUrl"), d.get("year"),
            d.get("filmLength"), d.get("slogan"), d.get("description"), d.get("shortDescription"),
            d.get("editorAnnotation"), int(bool(d.get("isTicketsAvailable"))), d.get("productionStatus"),
            d.get("type"), d.get("ratingMpaa"), d.get("ratingAgeLimits"),
            int(bool(d.get("hasImax"))) if d.get("hasImax") is not None else None,
            int(bool(d.get("has3D"))) if d.get("has3D") is not None else None,
            d.get("lastSync"), d.get("startYear"), d.get("endYear"),
            int(bool(d.get("serial"))) if d.get("serial") is not None else None,
            int(bool(d.get("shortFilm"))) if d.get("shortFilm") is not None else None,
            int(bool(d.get("completed"))) if d.get("completed") is not None else None,
            now_iso(),
        ),
    )
    conn.execute("DELETE FROM kp_film_countries WHERE kinopoisk_id=?", (kp_id,))
    for c in d.get("countries") or []:
        if c.get("country"):
            conn.execute("INSERT OR IGNORE INTO kp_film_countries VALUES (?,?)", (kp_id, c["country"]))
    conn.execute("DELETE FROM kp_film_genres WHERE kinopoisk_id=?", (kp_id,))
    for g in d.get("genres") or []:
        if g.get("genre"):
            conn.execute("INSERT OR IGNORE INTO kp_film_genres VALUES (?,?)", (kp_id, g["genre"]))


def ingest_staff(conn, kp_id, body):
    conn.execute("DELETE FROM kp_staff WHERE kinopoisk_id=?", (kp_id,))
    for m in json.loads(body):
        character = split_character(m.get("description"), m.get("nameRu")) \
            if m.get("professionKey") == "ACTOR" else None
        conn.execute(
            """
            INSERT OR REPLACE INTO kp_staff (
              kinopoisk_id, staff_id, profession_key, name_ru, name_en,
              description, character_name, poster_url, profession_text
            ) VALUES (?,?,?,?,?,?,?,?,?)
            """,
            (kp_id, m["staffId"], m.get("professionKey") or "", m.get("nameRu"), m.get("nameEn"),
             m.get("description"), character, m.get("posterUrl"), m.get("professionText")),
        )


def ingest_box_office(conn, kp_id, body):
    conn.execute("DELETE FROM kp_box_office WHERE kinopoisk_id=?", (kp_id,))
    for item in json.loads(body).get("items", []):
        conn.execute(
            "INSERT OR REPLACE INTO kp_box_office VALUES (?,?,?,?,?,?)",
            (kp_id, item.get("type"), item.get("amount"), item.get("currencyCode"),
             item.get("name"), item.get("symbol")),
        )


def ingest_videos(conn, kp_id, body):
    conn.execute("DELETE FROM kp_videos WHERE kinopoisk_id=?", (kp_id,))
    for item in json.loads(body).get("items", []):
        if item.get("url"):
            conn.execute("INSERT OR REPLACE INTO kp_videos VALUES (?,?,?,?)",
                         (kp_id, item["url"], item.get("name"), item.get("site")))


def ingest_awards(conn, kp_id, body):
    conn.execute("""DELETE FROM kp_award_persons WHERE award_id IN
                    (SELECT id FROM kp_awards WHERE kinopoisk_id=?)""", (kp_id,))
    conn.execute("DELETE FROM kp_awards WHERE kinopoisk_id=?", (kp_id,))
    for item in json.loads(body).get("items", []):
        cur = conn.execute(
            "INSERT INTO kp_awards (kinopoisk_id, name, win, nomination_name, year, image_url) VALUES (?,?,?,?,?,?)",
            (kp_id, item.get("name"), int(bool(item.get("win"))), item.get("nominationName"),
             item.get("year"), item.get("imageUrl")),
        )
        award_id = cur.lastrowid
        for p in item.get("persons") or []:
            conn.execute(
                "INSERT INTO kp_award_persons VALUES (?,?,?,?)",
                (award_id, p.get("kinopoiskId"), p.get("nameRu"), p.get("nameEn")),
            )


def ingest_seasons(conn, kp_id, body):
    conn.execute("DELETE FROM kp_episodes WHERE kinopoisk_id=?", (kp_id,))
    for season in json.loads(body).get("items", []):
        season_number = season.get("number")
        for ep in season.get("episodes") or []:
            conn.execute(
                "INSERT OR REPLACE INTO kp_episodes VALUES (?,?,?,?,?,?,?)",
                (kp_id, season_number, ep.get("episodeNumber"), ep.get("nameRu"),
                 ep.get("nameEn"), ep.get("synopsis"), ep.get("releaseDate")),
            )


def ingest_person(conn, person_id, body):
    d = json.loads(body)
    conn.execute(
        """
        INSERT INTO kp_persons (
          person_id, web_url, name_ru, name_en, sex, poster_url, growth, birthday,
          death, age, birthplace, deathplace, has_awards, profession, fetched_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(person_id) DO UPDATE SET fetched_at=excluded.fetched_at
        """,
        (d["personId"], d.get("webUrl"), d.get("nameRu"), d.get("nameEn"), d.get("sex"),
         d.get("posterUrl"), d.get("growth"), d.get("birthday"), d.get("death"), d.get("age"),
         d.get("birthplace"), d.get("deathplace"), d.get("hasAwards"), d.get("profession"), now_iso()),
    )
    conn.execute("DELETE FROM kp_person_facts WHERE person_id=?", (person_id,))
    for i, fact in enumerate(d.get("facts") or []):
        conn.execute("INSERT INTO kp_person_facts VALUES (?,?,?)", (person_id, i, fact))
    conn.execute("DELETE FROM kp_person_spouses WHERE person_id=?", (person_id,))
    for s in d.get("spouses") or []:
        conn.execute(
            "INSERT OR REPLACE INTO kp_person_spouses VALUES (?,?,?,?,?,?,?,?,?)",
            (person_id, s.get("personId"), s.get("name"), int(bool(s.get("divorced"))),
             s.get("divorcedReason"), s.get("sex"), s.get("children"), s.get("webUrl"), s.get("relation")),
        )
    conn.execute("DELETE FROM kp_person_films WHERE person_id=?", (person_id,))
    for f in d.get("films") or []:
        conn.execute(
            "INSERT OR REPLACE INTO kp_person_films VALUES (?,?,?,?,?,?,?,?)",
            (person_id, f.get("filmId"), f.get("nameRu"), f.get("nameEn"), f.get("rating"),
             int(bool(f.get("general"))), f.get("description"), f.get("professionKey")),
        )


INGESTERS = {
    "details": ingest_details,
    "staff": ingest_staff,
    "box_office": ingest_box_office,
    "videos": ingest_videos,
    "awards": ingest_awards,
    "seasons": ingest_seasons,
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-key", default=os.environ.get("KINOPOISK_API_KEY"))
    parser.add_argument("--skip-images", action="store_true",
                         help="derive tables from the raw cache only, no new requests")
    args = parser.parse_args()

    if not PROBE_DB.exists():
        sys.exit(f"{PROBE_DB} not found — run probe.py first.")

    probe = sqlite3.connect(PROBE_DB)
    out = sqlite3.connect(OUT_DB)
    out.executescript(SCHEMA_PATH.read_text())

    rows = probe.execute(
        "SELECT kinopoisk_id, endpoint, bucket, raw_json FROM probe_responses WHERE status_code=200"
    ).fetchall()

    film_ids = set()
    for kp_id, endpoint, bucket, raw_json in rows:
        if endpoint in INGESTERS and bucket != "person_sample":
            INGESTERS[endpoint](out, kp_id, raw_json)
            film_ids.add(kp_id)
        elif endpoint == "person_detail":
            ingest_person(out, kp_id, raw_json)
    out.commit()
    print(f"Derived tables from {len(rows)} cached responses across {len(film_ids)} films.")

    if not args.skip_images:
        if not args.api_key:
            sys.exit("Need --api-key (or KINOPOISK_API_KEY) to fetch /images, "
                      "or pass --skip-images to just re-derive the other tables.")
        for kp_id in sorted(film_ids):
            status, body = fetch(f"/api/v2.2/films/{kp_id}/images?type=STILL&page=1", args.api_key)
            print(f"  [images] {kp_id} -> {status}")
            if status == 200:
                out.execute("DELETE FROM kp_images WHERE kinopoisk_id=? AND type='STILL'", (kp_id,))
                for item in json.loads(body).get("items", []):
                    out.execute(
                        "INSERT OR REPLACE INTO kp_images VALUES (?,?,?,?)",
                        (kp_id, "STILL", item.get("imageUrl"), item.get("previewUrl")),
                    )
                out.commit()
            time.sleep(REQUEST_DELAY)

    print(f"\nDone. Structured tables in {OUT_DB}.")
    out.close()
    probe.close()


if __name__ == "__main__":
    main()
