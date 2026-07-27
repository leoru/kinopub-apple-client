#!/usr/bin/env python3
"""
Loads kinopoisk.ru's own editorial "Lists" — the ones with slugs like
oscars_2022, hbo_best, series_about_vampires — which live only on the actual
website, not this API. Direct HTTP requests to these pages redirect straight
to a Yandex SSO login (confirmed, not just a captcha), so there's no plain
requests-based way to fetch them; this data was scraped from the rendered
page in a real, already-authenticated Chrome session (via the browser tool),
extracting film/series ids straight out of the DOM. That's a one-time,
interactive step, not something this script re-runs — this script just loads
the already-scraped results below into kp_web_lists / kp_web_list_films, and
stubs each id into kp_films so probe.py/ingest.py can later fill in the real
title/year/rating for any of them.

Not scraped: `series-top250` — confirmed identical, same ids same order, to
the API's own TOP_250_TV_SHOWS collection (already in kp_collections). The 4
numbered "category" pages the request also named (/lists/categories/movies/
5, 17, 18, 2) turned out to be tab indexes (Сборы, Направления, Критика,
Онлайн-кинотеатр) — each listing dozens of *other* named lists rather than
being a film list itself — so nothing to scrape there directly; say which of
those sub-lists matter and they can be added the same way.

Usage:
  python3 web_lists.py
"""
import sqlite3
from datetime import datetime, timezone
from pathlib import Path

DATA_DIR = Path(__file__).parent / "data"
OUT_DB = DATA_DIR / "kinopoisk.db"
SCHEMA_PATH = Path(__file__).parent / "schema.sql"

# Scraped 2026-07-27 from a logged-in kinopoisk.ru session.
LISTS = {
    "movies/oscars_2022": {
        "title": "«Оскар»-2022: лауреаты",
        "ids": [1311466, 1262931, 1263429, 409424, 1272469, 839653, 1397888,
                1340710, 775278, 4382259, 804662, 706019, 1355265, 4470495, 4853660],
    },
    "movies/series_about_vampires": {
        "title": "Сериалы про вампиров",
        "ids": [1224067, 1113116, 1108681, 1120247, 415001, 589167, 178707,
                1202266, 676525, 453191, 762203, 1405843, 81344, 737843, 461353,
                1009526, 961141, 161099, 1048344, 782994, 308848, 698086, 4398350,
                573577, 395052, 808400, 906742, 4661122, 1355158, 4414040, 677719,
                305715, 706635, 229675, 503686, 1192755, 255994, 4672347],
    },
    "movies/100_greatest_TVseries": {
        "title": "100 великих сериалов XXI века",
        "ids": [
            # page 1
            404900, 464963, 1227803, 84358, 681831, 767379, 391889, 402955,
            986788, 991739, 581937, 253245, 915196, 893361, 104122, 655800,
            502838, 178710, 685246, 818708, 796660, 924910, 306084, 1178445,
            574688, 574497, 958500, 947758, 818185, 882408, 591929, 77039,
            568326, 1312007, 737589, 251568, 1045553, 1147693, 1309707, 716587,
            460586, 378244, 401522, 471825, 713333, 994468, 733419, 474779,
            252089, 737705,
            # page 2
            1253633, 821565, 859908, 1048143, 195523, 1228254, 1043400,
            1301710, 178720, 257386, 1254133, 1363058, 181807, 977755,
            1394680, 472329, 1044487, 1008365, 1032606, 401515, 1046272,
            394375, 1277987, 258048, 863009, 1197956, 839356, 79564, 1162628,
            401152, 1048602, 1007426, 1114955, 277537, 784529, 493098, 571335,
            255671, 840077, 518192, 682255, 1046206, 602284, 258550, 789914,
            1203040, 1343318, 455368, 4510176, 745562,
        ],
    },
    "movies/hbo_best": {
        "title": "Шедевры HBO",
        "ids": [464963, 79848, 986788, 402955, 77042, 681831, 2000461, 1316601,
                572049, 1254133, 1227803, 1178445, 195523, 723959, 733419,
                474779, 947758, 784529, 1046272, 181807, 568326, 257386,
                933326, 972587, 214333, 1406458, 277548, 5030035, 4510176, 1272547],
    },
}


def now_iso():
    return datetime.now(timezone.utc).isoformat()


def main():
    conn = sqlite3.connect(OUT_DB)
    conn.executescript(SCHEMA_PATH.read_text())

    for slug, data in LISTS.items():
        ids = data["ids"]
        conn.execute(
            "INSERT OR REPLACE INTO kp_web_lists VALUES (?,?,?,?)",
            (slug, data["title"], len(ids), now_iso()),
        )
        conn.execute("DELETE FROM kp_web_list_films WHERE slug=?", (slug,))
        for rank, kp_id in enumerate(ids, start=1):
            conn.execute(
                "INSERT OR REPLACE INTO kp_web_list_films VALUES (?,?,?,?)",
                (slug, rank, kp_id, None),
            )
            conn.execute(
                "INSERT OR IGNORE INTO kp_films (kinopoisk_id, fetched_at) VALUES (?, '')",
                (kp_id,),
            )
        print(f"{slug}: {len(ids)} ids")

    conn.commit()
    print(f"\nDone. Written to {OUT_DB}.")
    conn.close()


if __name__ == "__main__":
    main()
