-- Structured Kinopoisk Unofficial tables. One concept per table, one field per
-- column, named straight off the API docs — no raw-JSON blobs. `probe.db`
-- (raw_json per endpoint) stays the untouched source cache; this is what gets
-- derived from it, and what a real client would query.

CREATE TABLE IF NOT EXISTS kp_films (
  kinopoisk_id INTEGER PRIMARY KEY,
  kinopoisk_hd_id TEXT,
  imdb_id TEXT,
  name_ru TEXT,
  name_en TEXT,
  name_original TEXT,
  poster_url TEXT,
  poster_url_preview TEXT,
  cover_url TEXT,
  logo_url TEXT,
  reviews_count INTEGER,
  rating_good_review REAL,
  rating_good_review_vote_count INTEGER,
  rating_kinopoisk REAL,
  rating_kinopoisk_vote_count INTEGER,
  rating_imdb REAL,
  rating_imdb_vote_count INTEGER,
  rating_film_critics REAL,
  rating_film_critics_vote_count INTEGER,
  rating_await REAL,
  rating_await_count INTEGER,
  rating_rf_critics REAL,
  rating_rf_critics_vote_count INTEGER,
  web_url TEXT,
  year INTEGER,
  film_length INTEGER,
  slogan TEXT,
  description TEXT,
  short_description TEXT,
  editor_annotation TEXT,
  is_tickets_available INTEGER,
  production_status TEXT,
  type TEXT,
  rating_mpaa TEXT,
  rating_age_limits TEXT,
  has_imax INTEGER,
  has_3d INTEGER,
  last_sync TEXT,
  start_year INTEGER,
  end_year INTEGER,
  serial INTEGER,
  short_film INTEGER,
  completed INTEGER,
  fetched_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS kp_film_countries (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  country TEXT NOT NULL,
  PRIMARY KEY (kinopoisk_id, country)
);

CREATE TABLE IF NOT EXISTS kp_film_genres (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  genre TEXT NOT NULL,
  PRIMARY KEY (kinopoisk_id, genre)
);

-- One row per (film, credited person, profession) — a person can appear twice
-- with two profession_keys (e.g. actor + producer) on the same title.
CREATE TABLE IF NOT EXISTS kp_staff (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  staff_id INTEGER NOT NULL,
  profession_key TEXT NOT NULL,
  name_ru TEXT,
  name_en TEXT,
  description TEXT,       -- raw "Actor Name — Character Name" as the API sends it
  character_name TEXT,     -- parsed out of description for ACTOR rows when possible
  poster_url TEXT,
  profession_text TEXT,
  PRIMARY KEY (kinopoisk_id, staff_id, profession_key)
);

CREATE TABLE IF NOT EXISTS kp_box_office (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  type TEXT NOT NULL,       -- BUDGET / RUS / WORLD / USA / MARKETING ...
  amount INTEGER,
  currency_code TEXT,
  currency_name TEXT,
  currency_symbol TEXT,
  PRIMARY KEY (kinopoisk_id, type)
);

CREATE TABLE IF NOT EXISTS kp_videos (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  url TEXT NOT NULL,
  name TEXT,
  site TEXT,
  PRIMARY KEY (kinopoisk_id, url)
);

CREATE TABLE IF NOT EXISTS kp_awards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  name TEXT,
  win INTEGER,
  nomination_name TEXT,
  year INTEGER,
  image_url TEXT
);

CREATE TABLE IF NOT EXISTS kp_award_persons (
  award_id INTEGER NOT NULL REFERENCES kp_awards(id),
  kinopoisk_person_id INTEGER,
  name_ru TEXT,
  name_en TEXT
);

CREATE TABLE IF NOT EXISTS kp_episodes (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  season_number INTEGER NOT NULL,
  episode_number INTEGER NOT NULL,
  name_ru TEXT,
  name_en TEXT,
  synopsis TEXT,
  release_date TEXT,
  PRIMARY KEY (kinopoisk_id, season_number, episode_number)
);

CREATE TABLE IF NOT EXISTS kp_images (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  type TEXT NOT NULL,
  image_url TEXT NOT NULL,
  preview_url TEXT,
  PRIMARY KEY (kinopoisk_id, type, image_url)
);

CREATE TABLE IF NOT EXISTS kp_persons (
  person_id INTEGER PRIMARY KEY,
  web_url TEXT,
  name_ru TEXT,
  name_en TEXT,
  sex TEXT,
  poster_url TEXT,
  growth INTEGER,
  birthday TEXT,
  death TEXT,
  age INTEGER,
  birthplace TEXT,
  deathplace TEXT,
  has_awards INTEGER,
  profession TEXT,
  fetched_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS kp_person_facts (
  person_id INTEGER NOT NULL REFERENCES kp_persons(person_id),
  ordinal INTEGER NOT NULL,
  fact TEXT,
  PRIMARY KEY (person_id, ordinal)
);

CREATE TABLE IF NOT EXISTS kp_person_spouses (
  person_id INTEGER NOT NULL REFERENCES kp_persons(person_id),
  spouse_person_id INTEGER,
  name TEXT,
  divorced INTEGER,
  divorced_reason TEXT,
  sex TEXT,
  children INTEGER,
  web_url TEXT,
  relation TEXT,
  PRIMARY KEY (person_id, spouse_person_id)
);

-- Free — already in the same response we fetch for kp_persons, no extra request.
CREATE TABLE IF NOT EXISTS kp_person_films (
  person_id INTEGER NOT NULL REFERENCES kp_persons(person_id),
  film_id INTEGER NOT NULL,
  name_ru TEXT,
  name_en TEXT,
  rating REAL,
  general INTEGER,
  description TEXT,
  profession_key TEXT,
  PRIMARY KEY (person_id, film_id, profession_key)
);

-- The general connection graph: sequels, prequels, similars, remakes, spoofs...
-- (relation_type tells which). /sequels_and_prequels is a filtered subset of
-- exactly this same graph (relation_type IN ('SEQUEL','PREQUEL')) and isn't
-- stored separately — derive it from here instead of duplicating.
CREATE TABLE IF NOT EXISTS kp_relations (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  related_kinopoisk_id INTEGER NOT NULL,
  relation_type TEXT NOT NULL,
  name_ru TEXT,
  name_en TEXT,
  name_original TEXT,
  poster_url TEXT,
  PRIMARY KEY (kinopoisk_id, related_kinopoisk_id, relation_type)
);

-- Kept as its own table (distinct from kp_relations) even though every row here
-- also appears there with relation_type='SIMILAR' — asked for as a separate
-- entity, not derived, in case the two lists ever diverge.
CREATE TABLE IF NOT EXISTS kp_similars (
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  similar_kinopoisk_id INTEGER NOT NULL,
  name_ru TEXT,
  name_en TEXT,
  name_original TEXT,
  poster_url TEXT,
  PRIMARY KEY (kinopoisk_id, similar_kinopoisk_id)
);

-- First page only (see relations.py) — a sample, not the full review archive.
CREATE TABLE IF NOT EXISTS kp_reviews (
  kinopoisk_review_id INTEGER PRIMARY KEY,
  kinopoisk_id INTEGER NOT NULL REFERENCES kp_films(kinopoisk_id),
  type TEXT,
  date TEXT,
  positive_rating INTEGER,
  negative_rating INTEGER,
  author TEXT,
  title TEXT,
  description TEXT
);

-- Collections are a completely separate concept from per-film data: a named
-- top-level list containing many films, fetched independently (see
-- collections.py), not part of the per-film sweep.
CREATE TABLE IF NOT EXISTS kp_collections (
  type TEXT PRIMARY KEY,        -- the API's enum value, e.g. TOP_250_MOVIES
  total INTEGER,
  fetched_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS kp_collection_films (
  collection_type TEXT NOT NULL REFERENCES kp_collections(type),
  kinopoisk_id INTEGER NOT NULL,
  rank INTEGER,                 -- position in the collection as returned
  name_ru TEXT,
  name_en TEXT,
  name_original TEXT,
  year INTEGER,
  rating_kinopoisk REAL,
  rating_imdb REAL,
  PRIMARY KEY (collection_type, kinopoisk_id)
);

-- kinopoisk.ru's own editorial "Lists" feature (oscars_2022, hbo_best, etc.) —
-- distinct from kp_collections (this API's small generic enum). The site
-- requires a logged-in session for these (redirects to Yandex SSO otherwise),
-- so this is populated by scraping the rendered page in a real authenticated
-- browser (see web_lists.py) rather than a plain HTTP call like everything
-- else here. Only ids are scraped — title/year/rating for each id comes from
-- kp_films once that id runs through probe.py/ingest.py like any other title.
CREATE TABLE IF NOT EXISTS kp_web_lists (
  slug TEXT PRIMARY KEY,
  title TEXT,
  total INTEGER,
  fetched_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS kp_web_list_films (
  slug TEXT NOT NULL REFERENCES kp_web_lists(slug),
  rank INTEGER NOT NULL,
  kinopoisk_id INTEGER NOT NULL,
  kind TEXT,
  PRIMARY KEY (slug, rank)
);
