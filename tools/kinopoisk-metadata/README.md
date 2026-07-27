# Kinopoisk Unofficial metadata

Two-stage pipeline against the Kinopoisk Unofficial API (kinopoiskapiunofficial.tech),
tested against 8 real titles pulled from our own kino.pub snapshot
(`tools/kinopub-snapshot`) — movie/serial × new/old × Russian/foreign, plus one
representative cast member's person page per title.

1. **`probe.py`** fetches raw JSON from every endpoint below and caches it
   untouched in `data/probe.db` (one row per `(kinopoisk_id, endpoint)`). This
   is the source of truth — re-run `ingest.py` against it as the schema below
   evolves without spending API quota re-fetching.
2. **`ingest.py`** parses that cache into real typed tables (`schema.sql`) in
   `data/kinopoisk.db` — one column per API field, named straight off the docs,
   one-to-many data (countries, genres, cast, awards, episodes, images, facts,
   spouses, filmography) normalized into child tables rather than flattened or
   left as JSON. It also fetches `/images` fresh (the one endpoint not in the
   original probe) since that's new data, not something to re-derive.

## Usage

```
python3 probe.py --api-key <key>                  # full 8-title raw sweep
python3 probe.py --api-key <key> --ids 326,689     # just these kinopoisk ids

python3 ingest.py --api-key <key>                  # derive tables + fetch /images
python3 ingest.py --skip-images                    # just re-derive from the cache, no requests
```

Key: register free at kinopoiskapiunofficial.tech, pass via `--api-key` or
`KINOPOISK_API_KEY`.

## Tables (`data/kinopoisk.db`, see `schema.sql` for full columns)

| table | from | notes |
|---|---|---|
| `kp_films` (+ `kp_film_countries`, `kp_film_genres`) | `/films/{id}` | every documented field — tagline, descriptions, all 5 rating sources + vote counts, box-office flags, `hasImax`/`has3D`/`lastSync` included per your call to just keep them |
| `kp_staff` | `/staff?filmId=` | cast+crew; `character_name` is parsed out of the API's `"Actor — Character"` `description` string for ACTOR rows |
| `kp_box_office` | `/films/{id}/box_office` | budget + box office by region; empty for TV series |
| `kp_videos` | `/films/{id}/videos` | trailers/teasers |
| `kp_awards` (+ `kp_award_persons`) | `/films/{id}/awards` | name, win/nominated, nominationName, year, nominated persons |
| `kp_episodes` | `/films/{id}/seasons` | series only — per-episode RU synopsis + release date |
| `kp_images` | `/films/{id}/images?type=STILL` | one page of stills per film for now — other `type`s (POSTER/FAN_ART/WALLPAPER/...) and further pages exist but aren't pulled |
| `kp_persons` (+ `kp_person_facts`, `kp_person_spouses`, `kp_person_films`) | `/staff/{id}` | bio, birthplace, growth, trivia facts, spouses, and filmography — the last is free since it's already in the same response |

## Per-film connections (`relations.py`)

Separate script, separate concern from film attributes — writes to
`kp_relations` (the general connection graph — sequels, prequels, remakes,
spoofs, similars, whatever `relationType` says), `kp_similars` (kept as its
own table even though every row also appears in `kp_relations` with
`relation_type='SIMILAR'` — asked for as a distinct entity), and `kp_reviews`
(first page only, 3 votes classification + full review text).

`/sequels_and_prequels` isn't stored separately — confirmed it's exactly a
filtered view of `kp_relations` (`relation_type IN ('SEQUEL','PREQUEL')`), so
querying that is equivalent to fetching it fresh. Verified live: Брат (41519)
→ Брат 2 (41520), `relation_type='SEQUEL'`.

```
python3 relations.py --api-key <key>                # the 8 test titles + Брат 2
python3 relations.py --api-key <key> --ids 41519,41520
```

## Collections (`kp_collections.py`)

Named top-level lists — `/films/collections?type=X`, a completely different
concept from per-film data (one row per collection, many films each), so its
own script writing to `kp_collections` + `kp_collection_films`.

The `type` enum is undocumented. Confirmed working by trial: `TOP_250_MOVIES`,
`TOP_250_TV_SHOWS`, `FAMILY`, `VAMPIRE_THEME` (all fetched in full — 760 films
total). ~25 other guesses (genres, other named lists, kinopoisk.ru's own list
slugs) all rejected with a 400 — the real enum is small and mostly
undiscovered; pass more candidates with `--types` as they turn up.

```
python3 kp_collections.py --api-key <key>
python3 kp_collections.py --api-key <key> --types TOP_250_MOVIES,FAMILY
```

(Named `collections.py` originally — renamed to `kp_collections.py` because it
shadowed Python's own stdlib `collections` module.)

## kinopoisk.ru's own editorial lists (`web_lists.py`)

The specific named lists (`oscars_2022`, `hbo_best`, `100_greatest_TVseries`,
`series_about_vampires`, etc.) live only on the actual kinopoisk.ru website —
not this API, and its own `type` enum doesn't accept these slugs either.
Anonymous HTTP requests to these pages redirect straight to a Yandex SSO
login (confirmed — an actual auth wall, not a captcha), so there's no
requests-based way to fetch them.

Scraped instead from a real, already-logged-in Chrome session (via the
browser tool) — `window.__NEXT_DATA__`/Apollo state came back empty, so this
reads film/series ids straight out of the rendered DOM (`a[href*="/film/"]`
filtered to the anchor wrapping the title text, not the poster or button
anchors that point to the same id). That's a one-time interactive step, not
something `web_lists.py` re-runs — it just loads the already-scraped ids into
`kp_web_lists` / `kp_web_list_films`, and stubs each id into `kp_films` so
`probe.py`/`ingest.py` can fill in the real title/year/rating later for any of
them (165 stub ids waiting, as of this scrape — 2 already resolved: Breaking
Bad and Бригада both landed in `100_greatest_TVseries`, confirmed via their
existing `kp_films` rows).

Scraped: `oscars_2022` (15), `series_about_vampires` (38),
`100_greatest_TVseries` (100 — paginated, 50/page), `hbo_best` (30).

Not scraped:
- `series-top250` — confirmed identical (same ids, same order) to the API's
  own `TOP_250_TV_SHOWS` collection, already in `kp_collections`.
- The 4 numbered category pages (`/lists/categories/movies/5`, `/17`, `/18`,
  `/2`) — these turned out to be **tab indexes** (Сборы/box-office,
  Направления/movements, Критика/critics, Онлайн-кинотеатр/streaming
  respectively), each listing dozens of *other* named lists rather than being
  a film list itself. The general index at `/lists/categories/movies/` alone
  surfaces 30+ list slugs on just its "Фильмы" tab (`top500`, `popular-films`,
  `theme_vampire` — vampire *movies*, distinct from `series_about_vampires` —
  and more); say which specific ones matter and they can be scraped the same
  way as above.
- `facts`, `distributions`, `films/premieres`, `search-by-keyword` — not
  requested.

```
python3 web_lists.py
```
