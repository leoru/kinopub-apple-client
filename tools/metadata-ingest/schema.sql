-- Unified metadata record. One schema for every source.
--
-- Two layers, per policies/metadata-architecture §11a:
--   1. raw_payload  — every source row, untouched, whatever its shape
--   2. entities     — derived from raw, re-runnable without re-reading dumps
--
-- Nothing here is source-specific. A source contributes rows; which source a
-- fact came from is a column, never a table.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------- raw layer

CREATE TABLE IF NOT EXISTS raw_payload (
  source      TEXT NOT NULL,           -- kinopub | tvoe | kinopoisk | tmdb | …
  kind        TEXT NOT NULL,           -- item | film_detailed | staff | awards | …
  source_key  TEXT NOT NULL,           -- that source's own id for the row
  via         TEXT NOT NULL,           -- dump | donation | fetch
  body        TEXT NOT NULL,           -- JSON, exactly as received
  fetched_at  TEXT NOT NULL,
  PRIMARY KEY (source, kind, source_key)
);

-- "Did we already ask?" — answerable, including for misses.
CREATE TABLE IF NOT EXISTS fetch_log (
  source      TEXT NOT NULL,
  endpoint    TEXT NOT NULL,
  key         TEXT NOT NULL,
  status      INTEGER,
  fetched_at  TEXT NOT NULL,
  ttl_seconds INTEGER,
  note        TEXT,
  PRIMARY KEY (source, endpoint, key)
);

CREATE TABLE IF NOT EXISTS provider_health (
  provider     TEXT PRIMARY KEY,
  open_until   TEXT,
  open_reason  TEXT,
  consecutive  INTEGER NOT NULL DEFAULT 0,
  last_error   TEXT,
  last_ok_at   TEXT,
  calls_ok     INTEGER NOT NULL DEFAULT 0,
  calls_failed INTEGER NOT NULL DEFAULT 0,
  spent_today  INTEGER NOT NULL DEFAULT 0,
  spent_day    TEXT
);

CREATE TABLE IF NOT EXISTS ingest_run (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  source      TEXT NOT NULL,
  started_at  TEXT NOT NULL,
  finished_at TEXT,
  raw_rows    INTEGER DEFAULT 0,
  titles_new  INTEGER DEFAULT 0,
  titles_seen INTEGER DEFAULT 0,
  note        TEXT
);

-- ------------------------------------------------------------ entity layer

CREATE TABLE IF NOT EXISTS title (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  kind           TEXT,                 -- movie | series
  title_ru       TEXT,
  title_original TEXT,
  year           INTEGER,
  norm_original  TEXT,                 -- matching key, see match_key()
  norm_ru        TEXT,
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_title_norm_orig ON title(norm_original, year);
CREATE INDEX IF NOT EXISTS idx_title_norm_ru   ON title(norm_ru, year);

-- External ids are attributes with a confidence and a method, never the key.
CREATE TABLE IF NOT EXISTS title_external_id (
  title_id   INTEGER NOT NULL REFERENCES title(id),
  namespace  TEXT NOT NULL,            -- kinopub | imdb | kinopoisk | tvoe | tmdb | tvdb
  value      TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 1.0,
  method     TEXT NOT NULL,            -- dump | title_year | imdb | manual | …
  PRIMARY KEY (namespace, value)
);
CREATE INDEX IF NOT EXISTS idx_extid_title ON title_external_id(title_id);

CREATE TABLE IF NOT EXISTS person (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  name_ru  TEXT,
  name_en  TEXT,
  norm_ru  TEXT,
  norm_en  TEXT,
  photo    TEXT
);
CREATE INDEX IF NOT EXISTS idx_person_norm_ru ON person(norm_ru);
CREATE INDEX IF NOT EXISTS idx_person_norm_en ON person(norm_en);

CREATE TABLE IF NOT EXISTS person_external_id (
  person_id  INTEGER NOT NULL REFERENCES person(id),
  namespace  TEXT NOT NULL,            -- tmdb | imdb | kinopoisk_staff
  value      TEXT NOT NULL,
  PRIMARY KEY (namespace, value)
);

-- Uniqueness is enforced by COALESCE indexes throughout, not by composite
-- PRIMARY KEYs: a NULL never equals a NULL in SQLite, so a PK containing a
-- nullable column silently accepts duplicates and every re-run doubles the
-- table. Wrapping the nullable parts keeps NULL meaning "absent" in queries
-- while still making INSERT OR IGNORE/REPLACE idempotent.
CREATE TABLE IF NOT EXISTS title_credit (
  title_id      INTEGER NOT NULL REFERENCES title(id),
  person_id     INTEGER NOT NULL REFERENCES person(id),
  department    TEXT,                  -- actor | director | writer | producer | operator | …
  character     TEXT,
  ord           INTEGER,
  episode_count INTEGER,
  source        TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_title_credit
  ON title_credit(title_id, person_id, COALESCE(department,''), source);

-- `stable` records whether the URL survives a re-crawl (policy §4). tvoe's
-- cdnUrl does; its Next-resizer `url` does not.
CREATE TABLE IF NOT EXISTS image (
  title_id  INTEGER NOT NULL REFERENCES title(id),
  kind      TEXT NOT NULL,             -- poster | backdrop | logo | still | profile
  source    TEXT NOT NULL,
  url       TEXT NOT NULL,
  stable    INTEGER NOT NULL DEFAULT 1,
  lang      TEXT,
  width     INTEGER,
  height    INTEGER,
  color_top TEXT,                      -- filled by the colour pass, not at import
  color_bot TEXT,
  PRIMARY KEY (title_id, kind, source, url)
);

-- Every source kept side by side with its vote count. Never pre-averaged.
-- Three timestamps because they answer three different questions, and the
-- votes rule below needs all of them:
--   first_seen_at — when this source first had an opinion about this title
--   checked_at    — when we last confirmed the value, changed or not
--   changed_at    — when the number itself last moved
CREATE TABLE IF NOT EXISTS rating (
  title_id      INTEGER NOT NULL REFERENCES title(id),
  source        TEXT NOT NULL,         -- imdb | kinopoisk | kinopub | tvoe | tmdb | critics
  season        INTEGER,               -- NULL = whole title
  episode       INTEGER,
  value         REAL,
  votes         INTEGER,
  scale         REAL NOT NULL DEFAULT 10.0,
  fetched_at    TEXT NOT NULL,         -- kept as the legacy name for checked_at
  first_seen_at TEXT,
  changed_at    TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_rating
  ON rating(title_id, source, COALESCE(season,-1), COALESCE(episode,-1));

-- ---------------------------------------------------------- platform copies
--
-- A platform's *copy* of a title is not the title. tvoe's audio tracks, its
-- encode's intro offsets and its stream URLs describe tvoe's file — merging
-- them onto `title` would claim kino.pub has dub tracks it does not, and that
-- an intro ends at second 125 in an encode nobody here will ever play.
--
-- So: facts about a work go on `title`. Facts about one platform's copy go
-- here. Availability lands here too when it arrives.

CREATE TABLE IF NOT EXISTS title_copy (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  title_id     INTEGER NOT NULL REFERENCES title(id),
  platform     TEXT NOT NULL,          -- kinopub | tvoe | netflix | …
  platform_key TEXT NOT NULL,          -- that platform's id for its copy
  url          TEXT,
  seasons      INTEGER,
  updated_at   TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_title_copy ON title_copy(platform, platform_key);
CREATE INDEX IF NOT EXISTS idx_title_copy_title ON title_copy(title_id);

CREATE TABLE IF NOT EXISTS copy_video (
  copy_id    INTEGER NOT NULL REFERENCES title_copy(id),
  source_key TEXT NOT NULL,
  kind       TEXT,                     -- trailer | feature | episode
  season     INTEGER,
  episode    INTEGER,
  name       TEXT,
  duration   REAL,
  url        TEXT,
  thumbnail  TEXT,
  qualities  TEXT,                     -- JSON array
  audio      TEXT,                     -- JSON array: lang, channels, voiceover studio/type
  subtitles  TEXT,                     -- JSON array
  PRIMARY KEY (copy_id, source_key)
);

-- Intro/outro/recap markers, per encode. tvoe ships them for ~96% of its films
-- and they are only valid against tvoe's own file.
CREATE TABLE IF NOT EXISTS copy_segment (
  copy_id    INTEGER NOT NULL REFERENCES title_copy(id),
  source_key TEXT NOT NULL,            -- the video it belongs to
  kind       TEXT NOT NULL,            -- preview | credits | replay
  start_s    REAL,
  end_s      REAL,
  PRIMARY KEY (copy_id, source_key, kind)
);

-- Trailers are a fact about the work, not about a copy: a YouTube trailer plays
-- the same wherever it is referenced from.
CREATE TABLE IF NOT EXISTS trailer (
  title_id   INTEGER NOT NULL REFERENCES title(id),
  source     TEXT NOT NULL,
  source_key TEXT NOT NULL,
  kind       TEXT,
  name       TEXT,
  lang       TEXT,
  official   INTEGER,
  url        TEXT,
  PRIMARY KEY (source, source_key)
);
CREATE INDEX IF NOT EXISTS idx_trailer_title ON trailer(title_id);

-- Dated, with a validity window: "premiere", "new season", "leaving soon".
CREATE TABLE IF NOT EXISTS badge (
  title_id  INTEGER NOT NULL REFERENCES title(id),
  source    TEXT NOT NULL,
  type      TEXT NOT NULL,
  start_at  TEXT,
  finish_at TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_badge
  ON badge(title_id, source, type, COALESCE(start_at,''));

-- A season is an entity, not a number on an episode: it has its own poster,
-- its own synopsis, its own air window, and kino.pub addresses it as
-- `{kinopub_id}/s01`. Without this row there is nowhere to put any of that.
CREATE TABLE IF NOT EXISTS season (
  title_id    INTEGER NOT NULL REFERENCES title(id),
  number      INTEGER NOT NULL,
  name        TEXT,
  synopsis    TEXT,
  air_date    TEXT,
  end_date    TEXT,               -- "new season" needs its end as much as its start
  episode_cnt INTEGER,
  poster      TEXT,
  source      TEXT NOT NULL,
  PRIMARY KEY (title_id, number, source)
);

CREATE TABLE IF NOT EXISTS episode (
  title_id  INTEGER NOT NULL REFERENCES title(id),
  season    INTEGER,
  number    INTEGER,
  name_ru   TEXT,
  name_en   TEXT,
  synopsis  TEXT,
  air_date  TEXT,
  runtime   INTEGER,
  still     TEXT,
  source    TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_episode
  ON episode(title_id, COALESCE(season,-1), COALESCE(number,-1), source);

CREATE TABLE IF NOT EXISTS award (
  title_id   INTEGER NOT NULL REFERENCES title(id),
  source     TEXT NOT NULL,
  name       TEXT NOT NULL,
  nomination TEXT,
  year       INTEGER,
  won        INTEGER NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_award
  ON award(title_id, source, name, COALESCE(nomination,''), COALESCE(year,0));

CREATE TABLE IF NOT EXISTS genre (
  title_id INTEGER NOT NULL REFERENCES title(id),
  source   TEXT NOT NULL,
  name     TEXT NOT NULL,
  PRIMARY KEY (title_id, source, name)
);

CREATE TABLE IF NOT EXISTS country (
  title_id INTEGER NOT NULL REFERENCES title(id),
  source   TEXT NOT NULL,
  name     TEXT NOT NULL,
  PRIMARY KEY (title_id, source, name)
);

CREATE TABLE IF NOT EXISTS synopsis (
  title_id INTEGER NOT NULL REFERENCES title(id),
  source   TEXT NOT NULL,
  lang     TEXT NOT NULL DEFAULT 'ru',
  variant  TEXT NOT NULL DEFAULT 'full',  -- full | short | tagline
  text     TEXT NOT NULL,
  PRIMARY KEY (title_id, source, lang, variant)
);

CREATE TABLE IF NOT EXISTS fact (
  title_id INTEGER NOT NULL REFERENCES title(id),
  source   TEXT NOT NULL,
  text     TEXT NOT NULL,
  spoiler  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (title_id, source, text)
);
