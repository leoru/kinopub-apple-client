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
CREATE TABLE IF NOT EXISTS rating (
  title_id   INTEGER NOT NULL REFERENCES title(id),
  source     TEXT NOT NULL,            -- imdb | kinopoisk | kinopub | tvoe | tmdb | critics
  season     INTEGER,                  -- NULL = whole title
  episode    INTEGER,
  value      REAL,
  votes      INTEGER,
  scale      REAL NOT NULL DEFAULT 10.0,
  fetched_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_rating
  ON rating(title_id, source, COALESCE(season,-1), COALESCE(episode,-1));

CREATE TABLE IF NOT EXISTS video (
  title_id   INTEGER NOT NULL REFERENCES title(id),
  source     TEXT NOT NULL,
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
  PRIMARY KEY (source, source_key)
);
CREATE INDEX IF NOT EXISTS idx_video_title ON video(title_id);

-- Intro/outro/recap markers. tvoe ships these for ~96% of its films.
CREATE TABLE IF NOT EXISTS segment (
  source     TEXT NOT NULL,
  source_key TEXT NOT NULL,            -- the video it belongs to
  title_id   INTEGER NOT NULL REFERENCES title(id),
  kind       TEXT NOT NULL,            -- preview | credits | replay
  start_s    REAL,
  end_s      REAL,
  PRIMARY KEY (source, source_key, kind)
);

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

CREATE TABLE IF NOT EXISTS episode (
  title_id  INTEGER NOT NULL REFERENCES title(id),
  season    INTEGER,
  number    INTEGER,
  name_ru   TEXT,
  name_en   TEXT,
  synopsis  TEXT,
  air_date  TEXT,
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
