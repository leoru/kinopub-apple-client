#!/usr/bin/env python3
"""Regression tests. `python3 tests.py` or `make test`. Stdlib `unittest`, no deps.

Every case here is a bug that already happened, not a hypothetical:

- `rating` doubled on every re-run because a composite PRIMARY KEY containing a
  nullable column does not dedupe in SQLite.
- A stale payload could walk a rating backwards.
- OMDb's "Invalid API key" was written into `fetch_log` as "this title does not
  exist", so those titles would never be asked again.
- Cross-alphabet name matching silently matched nothing, and looked like a
  provider problem for weeks.
"""

from __future__ import annotations

import gzip
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import common
import registry
from common import add_rating, connect, match_key, resolve_person, resolve_title


class RecordTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.conn = connect(Path(self.tmp.name) / "test.db")

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    def make_title(self, **kwargs):
        defaults = dict(ids={}, kind="movie", title_ru="Тест",
                        title_original="Test", year=2020)
        defaults.update(kwargs)
        title_id, _ = resolve_title(self.conn, **defaults)
        return title_id


class TestRatingMonotonicity(RecordTestCase):
    """Vote counts only grow, so they are a free clock. Never regress on one."""

    def test_stale_payload_cannot_lower_a_rating(self):
        title = self.make_title()
        add_rating(self.conn, title, "imdb", 7.0, 1000)
        add_rating(self.conn, title, "imdb", 6.5, 900)   # older than what we hold
        row = self.conn.execute(
            "SELECT value, votes FROM rating WHERE title_id=? AND source='imdb'", (title,)
        ).fetchone()
        self.assertEqual((row["value"], row["votes"]), (7.0, 1000))

    def test_newer_payload_wins(self):
        title = self.make_title()
        add_rating(self.conn, title, "imdb", 7.0, 1000)
        add_rating(self.conn, title, "imdb", 7.2, 1500)
        row = self.conn.execute(
            "SELECT value, votes FROM rating WHERE title_id=? AND source='imdb'", (title,)
        ).fetchone()
        self.assertEqual((row["value"], row["votes"]), (7.2, 1500))

    def test_a_rejected_write_still_records_that_we_looked(self):
        title = self.make_title()
        add_rating(self.conn, title, "imdb", 7.0, 1000)
        before = self.conn.execute(
            "SELECT changed_at FROM rating WHERE title_id=?", (title,)).fetchone()["changed_at"]
        add_rating(self.conn, title, "imdb", 6.5, 900)
        after = self.conn.execute(
            "SELECT fetched_at, changed_at FROM rating WHERE title_id=?", (title,)).fetchone()
        self.assertEqual(after["changed_at"], before,
                         "a rejected value must not look like a change")
        self.assertIsNotNone(after["fetched_at"])

    def test_first_write_with_no_votes_is_still_stored(self):
        title = self.make_title()
        add_rating(self.conn, title, "tvoe", 6.7, None)
        row = self.conn.execute(
            "SELECT value, votes FROM rating WHERE title_id=? AND source='tvoe'", (title,)
        ).fetchone()
        self.assertEqual(row["value"], 6.7)
        self.assertIsNone(row["votes"])

    def test_sources_do_not_collide(self):
        title = self.make_title()
        add_rating(self.conn, title, "imdb", 7.0, 1000)
        add_rating(self.conn, title, "rotten_tomatoes", 85.0, None, scale=100.0)
        self.assertEqual(
            self.conn.execute("SELECT count(*) FROM rating WHERE title_id=?",
                              (title,)).fetchone()[0], 2)

    def test_season_and_title_ratings_are_separate_rows(self):
        """NULL season vs season 1: the COALESCE index has to keep these apart."""
        title = self.make_title()
        add_rating(self.conn, title, "tmdb", 8.0, 100)
        add_rating(self.conn, title, "tmdb", 8.5, 50, season=1)
        self.assertEqual(
            self.conn.execute("SELECT count(*) FROM rating WHERE title_id=?",
                              (title,)).fetchone()[0], 2)


class TestIdempotency(RecordTestCase):
    """A composite PK with a nullable column silently accepts duplicates."""

    def test_repeated_identical_writes_do_not_accumulate(self):
        title = self.make_title()
        for _ in range(3):
            add_rating(self.conn, title, "imdb", 7.0, 1000)
            self.conn.execute(
                "INSERT OR IGNORE INTO title_credit(title_id,person_id,department,character,"
                "ord,episode_count,source) VALUES (?,?,NULL,NULL,NULL,NULL,'tmdb')",
                (title, resolve_person(self.conn, name_en="Someone")))
            self.conn.execute(
                "INSERT OR IGNORE INTO award(title_id,source,name,nomination,year,won)"
                " VALUES (?,'kinopoisk','Oscar',NULL,NULL,1)", (title,))
        for table in ("rating", "title_credit", "award"):
            self.assertEqual(
                self.conn.execute(f"SELECT count(*) FROM {table}").fetchone()[0], 1,
                f"{table} duplicated on re-run")


class TestMatching(RecordTestCase):
    def test_diacritics_fold_but_alphabets_do_not(self):
        self.assertEqual(match_key("Rémi Bezançon"), match_key("Remi Bezancon"))
        self.assertNotEqual(match_key("Реми Безансон"), match_key("Remi Bezancon"),
                            "cross-alphabet matching must be an id join, never a string join")

    def test_punctuation_and_case_are_ignored(self):
        self.assertEqual(match_key("Spider-Man: No Way Home"),
                         match_key("spider man no way home"))

    def test_empty_input_is_none_not_empty_string(self):
        self.assertIsNone(match_key(""))
        self.assertIsNone(match_key(None))

    def test_an_external_id_beats_a_title_match(self):
        first = self.make_title(ids={"kinopub": 1}, title_original="Dune", year=2021)
        common.link_external(self.conn, first, "kinopub", 1, "dump")
        again, method = resolve_title(self.conn, ids={"kinopub": 1},
                                      title_original="Something Else", year=1999)
        self.assertEqual(again, first)
        self.assertEqual(method, "id:kinopub")

    def test_year_drifts_by_one_between_sources(self):
        first = self.make_title(title_original="Dune", year=2021)
        again, method = resolve_title(self.conn, ids={}, title_original="Dune", year=2020)
        self.assertEqual(again, first)
        self.assertTrue(method.startswith("title_year"))

    def test_a_second_source_reuses_the_row_rather_than_duplicating_it(self):
        first = self.make_title(title_original="The Vanishing", year=1988)
        again, method = resolve_title(self.conn, ids={},
                                      title_original="The Vanishing", year=1988)
        self.assertEqual(again, first)
        self.assertTrue(method.startswith("title_year"))

    def test_an_ambiguous_title_creates_a_new_row_rather_than_guessing(self):
        # Two genuine same-title-same-year rows can only be produced by the
        # spine, which never fuzzy-matches; after that, a fuzzy caller must
        # refuse to pick one of them.
        for _ in range(2):
            self.make_title(title_original="The Vanishing", year=1988,
                            allow_title_match=False)
        _, method = resolve_title(self.conn, ids={},
                                  title_original="The Vanishing", year=1988)
        self.assertEqual(method, "new", "two candidates is not a match")
        self.assertEqual(
            self.conn.execute("SELECT count(*) FROM title WHERE norm_original='the vanishing'")
            .fetchone()[0], 3)

    def test_kinopub_rows_never_fuzzy_match_each_other(self):
        """Remakes share a title and a year; only ids may join them."""
        self.make_title(title_original="Dune", year=2021, allow_title_match=False)
        _, method = resolve_title(self.conn, ids={}, title_original="Dune", year=2021,
                                  allow_title_match=False)
        self.assertEqual(method, "new")

    def test_a_person_id_merges_two_spellings(self):
        first = resolve_person(self.conn, name_en="Rémi Bezançon", ids={"tmdb": 71506})
        again = resolve_person(self.conn, name_ru="Реми Безансон", ids={"tmdb": 71506})
        self.assertEqual(first, again, "the id is the join key, not the name")
        row = self.conn.execute("SELECT name_ru, name_en FROM person WHERE id=?",
                                (first,)).fetchone()
        self.assertEqual(row["name_en"], "Rémi Bezançon")
        self.assertEqual(row["name_ru"], "Реми Безансон")


class TestOMDbErrorTriage(unittest.TestCase):
    """Three very different conditions arrive in one shape, over HTTP 200."""

    @staticmethod
    def is_answer_about_the_title(payload):
        if payload.get("Response") != "False":
            return True
        return "not found" in (payload.get("Error") or "").lower()

    def test_missing_title_is_an_answer(self):
        self.assertTrue(self.is_answer_about_the_title(
            {"Response": "False", "Error": "Movie not found!"}))

    def test_invalid_key_is_not_an_answer_about_the_title(self):
        self.assertFalse(self.is_answer_about_the_title(
            {"Response": "False", "Error": "Invalid API key!"}))

    def test_quota_exhaustion_is_not_an_answer_about_the_title(self):
        self.assertFalse(self.is_answer_about_the_title(
            {"Response": "False", "Error": "Request limit reached!"}))

    def test_numbers_arrive_as_formatted_strings(self):
        from fetch_omdb import parse_number
        self.assertEqual(parse_number("828,114"), 828114)
        self.assertEqual(parse_number("7.6/10"), 7.6)
        self.assertEqual(parse_number("85%"), 85)
        self.assertEqual(parse_number("67/100"), 67)
        self.assertEqual(parse_number("$389,813,101"), 389813101)
        self.assertIsNone(parse_number("N/A"))
        self.assertIsNone(parse_number(None))

    def test_the_shape_changes_by_type(self):
        """Series omit BoxOffice/DVD/Production/Website; a required-field decode breaks."""
        series = {"Response": "True", "Type": "series", "totalSeasons": "10",
                  "imdbRating": "8.9", "Ratings": []}
        self.assertNotIn("BoxOffice", series)
        self.assertTrue(self.is_answer_about_the_title(series))


class TestTokenBucket(unittest.TestCase):
    """A reservation cursor poisons the schedule; a bucket cannot."""

    def test_burst_passes_then_throttles(self):
        clock = [0.0]
        bucket = registry.TokenBucket(rps=2.0, burst=3, clock=lambda: clock[0])
        for _ in range(3):
            self.assertEqual(bucket.try_acquire(), 0.0)
        self.assertGreater(bucket.try_acquire(), 0.0, "burst spent, must now wait")

    def test_tokens_refill_over_time(self):
        clock = [0.0]
        bucket = registry.TokenBucket(rps=2.0, burst=1, clock=lambda: clock[0])
        self.assertEqual(bucket.try_acquire(), 0.0)
        self.assertGreater(bucket.try_acquire(), 0.0)
        clock[0] = 1.0                       # 2 tokens' worth of time
        self.assertEqual(bucket.try_acquire(), 0.0)

    def test_a_refused_call_spends_nothing(self):
        clock = [0.0]
        bucket = registry.TokenBucket(rps=1.0, burst=1, clock=lambda: clock[0])
        bucket.try_acquire()
        for _ in range(5):
            bucket.try_acquire()             # all refused
        clock[0] = 1.0
        self.assertEqual(bucket.try_acquire(), 0.0,
                         "refused calls must not push the schedule forward")


class TestCircuitBreaker(unittest.TestCase):
    def setUp(self):
        self.clock = [0.0]
        self.breaker = registry.CircuitBreaker(clock=lambda: self.clock[0])

    def test_a_bad_key_opens_immediately(self):
        opened = self.breaker.record_failure("omdb", registry.AUTH, message="Invalid API key!")
        self.assertTrue(opened, "auth failures must not need a threshold")
        self.assertFalse(self.breaker.allow("omdb"))

    def test_transient_failures_need_a_threshold(self):
        for _ in range(registry.FAILURE_THRESHOLD - 1):
            self.assertFalse(self.breaker.record_failure("tmdb", registry.TRANSIENT))
            self.assertTrue(self.breaker.allow("tmdb"))
        self.assertTrue(self.breaker.record_failure("tmdb", registry.TRANSIENT))
        self.assertFalse(self.breaker.allow("tmdb"))

    def test_success_resets_the_transient_count(self):
        self.breaker.record_failure("tmdb", registry.TRANSIENT)
        self.breaker.record_success("tmdb")
        self.breaker.record_failure("tmdb", registry.TRANSIENT)
        self.assertTrue(self.breaker.allow("tmdb"))

    def test_one_provider_does_not_block_another(self):
        self.breaker.record_failure("omdb", registry.AUTH)
        self.assertFalse(self.breaker.allow("omdb"))
        self.assertTrue(self.breaker.allow("tmdb"))

    def test_only_one_probe_is_admitted_after_the_cooldown(self):
        self.breaker.record_failure("omdb", registry.AUTH)
        self.clock[0] += registry.COOLDOWN[registry.AUTH] + 1
        self.assertTrue(self.breaker.allow("omdb"), "first caller probes")
        self.assertFalse(self.breaker.allow("omdb"), "no thundering herd")

    def test_a_successful_probe_closes_the_breaker(self):
        self.breaker.record_failure("omdb", registry.AUTH)
        self.clock[0] += registry.COOLDOWN[registry.AUTH] + 1
        self.breaker.allow("omdb")
        self.breaker.record_success("omdb")
        self.assertTrue(self.breaker.allow("omdb"))
        self.assertFalse(self.breaker.tripped("omdb"))

    def test_retry_after_is_honoured_over_the_default(self):
        self.breaker.record_failure("tmdb", registry.RATE_LIMIT, retry_after=5)
        self.clock[0] += 6
        self.assertTrue(self.breaker.allow("tmdb"))


class TestProviderSpecs(unittest.TestCase):
    def test_every_provider_declares_what_it_accepts_and_supplies(self):
        for name, spec in registry.PROVIDERS.items():
            self.assertEqual(name, spec.name)
            self.assertTrue(spec.accepts, f"{name} declares no id namespaces")
            self.assertTrue(spec.supplies, f"{name} declares no fields")
            self.assertIn(spec.auth, {"none", "system_key", "user_key", "oauth"})

    def test_omdb_only_accepts_imdb_so_it_can_never_resolve_identity(self):
        self.assertEqual(registry.PROVIDERS["omdb"].accepts, ("imdb",))

    def test_the_users_own_key_is_not_our_quota(self):
        self.assertEqual(registry.PROVIDERS["kinopoisk"].auth, "user_key")


class TestPlatformCopySeparation(RecordTestCase):
    """A platform's copy is not the work: streams must not become title facts."""

    def test_two_platforms_hold_separate_copies_of_one_title(self):
        title = self.make_title()
        first = common.upsert_copy(self.conn, title, "kinopub", 42)
        second = common.upsert_copy(self.conn, title, "tvoe", "abc")
        self.assertNotEqual(first, second)
        self.assertEqual(
            self.conn.execute("SELECT count(*) FROM title_copy WHERE title_id=?",
                              (title,)).fetchone()[0], 2)

    def test_a_copy_is_upserted_not_duplicated(self):
        title = self.make_title()
        first = common.upsert_copy(self.conn, title, "tvoe", "abc")
        again = common.upsert_copy(self.conn, title, "tvoe", "abc", url="/p/x")
        self.assertEqual(first, again)

    def test_skip_markers_belong_to_a_copy_and_not_to_the_title(self):
        title = self.make_title()
        copy_id = common.upsert_copy(self.conn, title, "tvoe", "abc")
        self.conn.execute(
            "INSERT INTO copy_segment(copy_id,source_key,kind,start_s,end_s)"
            " VALUES (?,'vid','credits',6072,NULL)", (copy_id,))
        columns = {row[1] for row in self.conn.execute("PRAGMA table_info(copy_segment)")}
        self.assertNotIn("title_id", columns,
                         "a segment reachable by title_id would imply it applies to every copy")




class TestRawSurvivesSchemaChanges(RecordTestCase):
    """The question this suite exists to answer: can we change the schema
    without re-spending quota? Until `--rederive` existed, the answer was no,
    and the README claimed otherwise."""

    def _paid_row(self, imdb="tt0111161"):
        title = self.make_title(ids={}, title_original="Shawshank", year=1994)
        common.link_external(self.conn, title, "imdb", imdb, "dump")
        common.store_raw(self.conn, "omdb", "title", imdb,
                         {"Response": "True", "Type": "movie", "imdbID": imdb,
                          "Ratings": [{"Source": "Rotten Tomatoes", "Value": "91%"}]},
                         via="fetch")
        return title

    def test_wipe_derived_keeps_the_layer_that_cost_quota(self):
        self._paid_row()
        common.wipe_derived(self.conn)
        self.assertEqual(common.fetched_raw_count(self.conn), 1,
                         "a schema change must never discard fetched payloads")
        self.assertEqual(
            self.conn.execute("SELECT count(*) FROM title").fetchone()[0], 0,
            "derived tables should have been cleared")

    def test_a_fetched_payload_can_be_replayed_without_network(self):
        import sources
        self._paid_row()
        common.wipe_derived(self.conn)
        # The spine has to exist again before a replay can attach to it.
        title = self.make_title(ids={}, title_original="Shawshank", year=1994)
        common.link_external(self.conn, title, "imdb", "tt0111161", "dump")
        sources.replay_omdb(self.conn)
        row = self.conn.execute(
            "SELECT value, scale FROM rating WHERE source='rotten_tomatoes'").fetchone()
        self.assertEqual((row["value"], row["scale"]), (91.0, 100.0))

    def test_fetched_and_dumped_rows_are_distinguishable(self):
        self._paid_row()
        common.store_raw(self.conn, "kinopub", "item", 1, {"id": 1}, via="dump")
        self.assertEqual(common.fetched_raw_count(self.conn), 1,
                         "only `via='fetch'` rows cost anything to replace")


class TestMigrations(RecordTestCase):
    def test_a_missing_column_is_added_in_place(self):
        self.conn.execute("ALTER TABLE rating DROP COLUMN changed_at")
        applied = common.migrate(self.conn)
        self.assertIn("rating.changed_at", applied)
        columns = {row[1] for row in self.conn.execute("PRAGMA table_info(rating)")}
        self.assertIn("changed_at", columns)

    def test_migrate_is_a_no_op_on_a_current_record(self):
        self.assertEqual(common.migrate(self.conn), [])


# ---------------------------------------------------------------- derivers
#
# The importers were the biggest untested surface in the pipeline: every test
# above exercised a helper, none exercised the code that actually reads a dump.

class TestKinopubDeriver(RecordTestCase):
    def setUp(self):
        super().setUp()
        import sources
        self.sources = sources
        path = Path(self.tmp.name) / "snapshot.db"
        source = sqlite3.connect(path)
        source.executescript("""
          CREATE TABLE items (id INTEGER PRIMARY KEY, type TEXT, subtype TEXT, title TEXT,
            title_ru TEXT, title_original TEXT, year INTEGER, countries TEXT, imdb_id INTEGER,
            imdb_rating REAL, imdb_votes INTEGER, kinopoisk_id INTEGER, kinopoisk_rating REAL,
            kinopoisk_votes INTEGER, kinopub_rating_votes INTEGER,
            kinopub_rating_percentage REAL, views INTEGER, poster_thumb TEXT, poster_wide TEXT,
            finished INTEGER, created_at INTEGER, updated_at INTEGER,
            first_synced_at TEXT NOT NULL, last_synced_at TEXT NOT NULL);
        """)
        source.execute(
            "INSERT INTO items VALUES (7,'serial',NULL,'Тест','Тест','Test Show',2019,"
            '\'["США"]\',111161,9.3,2900000,326,8.9,900000,50,88.0,10,NULL,NULL,0,0,0,\'x\',\'x\')')
        source.commit(); source.close()
        self._original = sources.KINOPUB_DB
        sources.KINOPUB_DB = path

    def tearDown(self):
        self.sources.KINOPUB_DB = self._original
        super().tearDown()

    def test_it_derives_ids_ratings_artwork_and_a_copy(self):
        self.sources.ingest_kinopub(self.conn)
        title = self.conn.execute("SELECT * FROM title").fetchone()
        self.assertEqual(title["kind"], "series", "serial must map to series")
        self.assertEqual(title["title_original"], "Test Show")

        ids = dict(self.conn.execute(
            "SELECT namespace, value FROM title_external_id").fetchall())
        self.assertEqual(ids["imdb"], "tt0111161", "numeric imdb id must be zero-padded")
        self.assertEqual(ids["kinopoisk"], "326")

        scales = dict(self.conn.execute("SELECT source, scale FROM rating").fetchall())
        self.assertEqual(scales["kinopub"], 100.0,
                         "kino.pub reports a like percentage, not a 10-point score")
        self.assertEqual(scales["imdb"], 10.0)

        self.assertTrue(self.conn.execute(
            "SELECT count(*) FROM image WHERE source='kinopub' AND url LIKE '%/big/7.jpg'"
        ).fetchone()[0], "artwork must be addressable by kino.pub id alone")
        self.assertEqual(self.conn.execute(
            "SELECT platform FROM title_copy").fetchone()["platform"], "kinopub")

    def test_a_second_run_changes_nothing(self):
        self.sources.ingest_kinopub(self.conn)
        counts = [self.conn.execute(f"SELECT count(*) FROM {t}").fetchone()[0]
                  for t in ("title", "rating", "image", "title_copy")]
        self.sources.ingest_kinopub(self.conn)
        again = [self.conn.execute(f"SELECT count(*) FROM {t}").fetchone()[0]
                 for t in ("title", "rating", "image", "title_copy")]
        self.assertEqual(counts, again)


class TestTvoeDeriver(RecordTestCase):
    def setUp(self):
        super().setUp()
        import sources
        self.sources = sources
        directory = Path(self.tmp.name) / "tvoe"
        directory.mkdir()
        item = {
            "_id": "abc", "name": "Супергёрл", "origName": "Supergirl",
            "dateReleased": "2026-06-24", "rating": 6.7, "url": "/p/x",
            "genres": ["Драма"], "countries": ["США"], "description": "полное",
            "shortDesc": "короткое", "seasonsCount": None,
            "badge": {"type": "premiere", "startAt": "2026-07-28", "finishAt": None},
            "persons": [{"name": "Крэйг Гиллеспи", "type": "director"}],
            "images": {
                "poster": {"cdnUrl": "https://static.cdn.tvoe.live/images/p.jpg",
                           "url": "https://tvoe.live/_next/image?url=p.jpg&w=384&q=75"},
                "cover": {"cdnUrl": "https://static.cdn.tvoe.live/images/c.jpg"},
                "logo": {"cdnUrl": "https://static.cdn.tvoe.live/images/l.jpg"}},
            "videos": {
                "films": [{"_id": "v1", "duration": 6499.4, "creditsStartTime": 6072,
                           "previewStartTime": 5, "previewEndTime": 25,
                           "audio": [{"lang": "RU"}], "subtitles": [{"lang": "EN"}],
                           "qualities": [{"type": "1080p"}]}],
                "trailers": [{"_id": "t1", "src": "/videos/t1"}],
                "seasons": []}}
        (directory / "catalog_films_detailed.json").write_text(json.dumps([item]))
        (directory / "catalog_serials_detailed.json").write_text("[]")
        self._original = sources.TVOE_DIR
        sources.TVOE_DIR = directory

    def tearDown(self):
        self.sources.TVOE_DIR = self._original
        super().tearDown()

    def test_streams_and_markers_belong_to_the_copy_not_the_title(self):
        self.sources.ingest_tvoe(self.conn)
        copy = self.conn.execute("SELECT * FROM title_copy WHERE platform='tvoe'").fetchone()
        self.assertIsNotNone(copy)
        video = self.conn.execute("SELECT * FROM copy_video WHERE copy_id=?",
                                  (copy["id"],)).fetchone()
        self.assertIn("RU", video["audio"], "dub tracks describe tvoe's file")
        segments = dict(self.conn.execute(
            "SELECT kind, start_s FROM copy_segment WHERE copy_id=?", (copy["id"],)).fetchall())
        self.assertEqual(segments["credits"], 6072)
        self.assertEqual(segments["preview"], 5)

    def test_a_trailer_is_a_fact_about_the_work(self):
        self.sources.ingest_tvoe(self.conn)
        self.assertEqual(self.conn.execute(
            "SELECT count(*) FROM trailer WHERE source='tvoe'").fetchone()[0], 1)
        self.assertEqual(self.conn.execute(
            "SELECT count(*) FROM copy_video WHERE kind='trailer'").fetchone()[0], 0)

    def test_only_the_durable_image_url_is_stored(self):
        self.sources.ingest_tvoe(self.conn)
        urls = [r[0] for r in self.conn.execute("SELECT url FROM image WHERE source='tvoe'")]
        self.assertTrue(all("static.cdn.tvoe.live" in u for u in urls))
        self.assertFalse(any("_next/image" in u for u in urls),
                         "the resizer URL carries w/q params and does not survive a re-crawl")

    def test_a_badge_keeps_its_validity_window(self):
        self.sources.ingest_tvoe(self.conn)
        badge = self.conn.execute("SELECT * FROM badge").fetchone()
        self.assertEqual(badge["type"], "premiere")
        self.assertEqual(badge["start_at"], "2026-07-28")

    def test_year_comes_from_the_release_date(self):
        self.sources.ingest_tvoe(self.conn)
        self.assertEqual(self.conn.execute("SELECT year FROM title").fetchone()[0], 2026)


class TestTMDBDerive(RecordTestCase):
    def payload(self, cast=60, crew=None):
        return {
            "vote_average": 8.1, "vote_count": 900, "overview": "текст",
            "poster_path": "/p.jpg", "genres": [{"id": 18, "name": "Drama"}],
            "external_ids": {"imdb_id": "tt1", "wikidata_id": "Q42", "tvdb_id": 77},
            "images": {"posters": [{"file_path": "/a.jpg", "width": 500, "height": 750,
                                    "iso_639_1": "ru"}], "backdrops": [], "logos": []},
            "keywords": {"keywords": [{"id": 9, "name": "heist"}]},
            "credits": {
                "cast": [{"id": i, "name": f"Actor {i}", "order": i,
                          "character": "X", "profile_path": "/x.jpg"}
                         for i in range(cast)],
                "crew": crew if crew is not None else [
                    {"id": 900, "name": "The Director", "job": "Director"},
                    {"id": 901, "name": "A Gaffer", "job": "Gaffer"}]},
            "videos": {"results": [{"key": "abc", "site": "YouTube", "type": "Trailer",
                                    "name": "T"}]},
            "watch/providers": {"results": {"RU": {"flatrate": [{"provider_name": "Okko"}]}}},
        }

    def test_cast_is_capped_at_thirty_by_billing_order(self):
        import fetch_tmdb
        title = self.make_title()
        fetch_tmdb.derive(self.conn, title, 1, "movie", self.payload(cast=60))
        rows = self.conn.execute(
            "SELECT ord FROM title_credit WHERE department='actor' ORDER BY ord").fetchall()
        self.assertEqual(len(rows), 30)
        self.assertEqual(rows[0]["ord"], 0, "the cap must keep the top billing, not an arbitrary 30")

    def test_crew_is_filtered_by_role_not_by_count(self):
        import fetch_tmdb
        title = self.make_title()
        fetch_tmdb.derive(self.conn, title, 1, "movie", self.payload())
        jobs = {r[0] for r in self.conn.execute(
            "SELECT department FROM title_credit WHERE department<>'actor'")}
        self.assertIn("director", jobs)
        self.assertNotIn("gaffer", jobs)

    def test_bridge_ids_are_captured(self):
        import fetch_tmdb
        title = self.make_title()
        fetch_tmdb.derive(self.conn, title, 1, "movie", self.payload())
        ids = dict(self.conn.execute(
            "SELECT namespace, value FROM title_external_id").fetchall())
        self.assertEqual(ids["wikidata"], "Q42")
        self.assertEqual(ids["tvdb"], "77")
        self.assertEqual(ids["tmdb"], "movie/1")

    def test_image_dimensions_survive_so_a_choice_can_be_argued(self):
        import fetch_tmdb
        title = self.make_title()
        fetch_tmdb.derive(self.conn, title, 1, "movie", self.payload())
        row = self.conn.execute(
            "SELECT width, height, lang FROM image WHERE source='tmdb' AND width IS NOT NULL"
        ).fetchone()
        self.assertEqual((row["width"], row["height"], row["lang"]), (500, 750, "ru"))

    def test_keyword_ids_are_kept_because_similarity_needs_them(self):
        import fetch_tmdb
        title = self.make_title()
        fetch_tmdb.derive(self.conn, title, 1, "movie", self.payload())
        row = self.conn.execute(
            "SELECT name FROM genre WHERE source='tmdb:keyword'").fetchone()
        self.assertTrue(row["name"].startswith("9:"), "a bare name cannot be joined on")


class TestIMDbDatasets(unittest.TestCase):
    """TSV with literal \\N for null, and an episode file that only makes sense
    joined against the ratings file."""

    def _write(self, directory, name, header, rows):
        path = Path(directory) / name
        with gzip.open(path, "wt", encoding="utf-8") as stream:
            stream.write("\t".join(header) + "\n")
            for row in rows:
                stream.write("\t".join(row) + "\n")
        return path

    def test_backslash_n_becomes_none(self):
        import import_imdb_datasets as imdb
        with tempfile.TemporaryDirectory() as tmp:
            path = self._write(tmp, "e.tsv.gz",
                               ["tconst", "parentTconst", "seasonNumber", "episodeNumber"],
                               [["tt2", "tt1", "\\N", "\\N"]])
            row = next(imdb.rows(path))
            self.assertIsNone(row["seasonNumber"])
            self.assertEqual(row["parentTconst"], "tt1")

    def test_only_episodes_of_series_we_hold_are_imported(self):
        import import_imdb_datasets as imdb
        with tempfile.TemporaryDirectory() as tmp:
            conn = connect(Path(tmp) / "t.db")
            title_id, _ = resolve_title(conn, ids={}, title_original="Show", year=2000)
            common.link_external(conn, title_id, "imdb", "tt1", "dump")
            episodes = self._write(tmp, "e.tsv.gz",
                                   ["tconst", "parentTconst", "seasonNumber", "episodeNumber"],
                                   [["tt2", "tt1", "1", "1"],
                                    ["tt9", "tt_unknown", "1", "1"]])
            ratings = self._write(tmp, "r.tsv.gz",
                                  ["tconst", "averageRating", "numVotes"],
                                  [["tt2", "9.5", "1000"], ["tt9", "1.0", "5"]])
            imdb.import_episode_ratings(conn, episodes, ratings,
                                        imdb.known_imdb_ids(conn))
            rows = conn.execute(
                "SELECT season, episode, value FROM rating WHERE season IS NOT NULL").fetchall()
            self.assertEqual(len(rows), 1, "an episode of an unknown series must be skipped")
            self.assertEqual((rows[0]["season"], rows[0]["episode"], rows[0]["value"]),
                             (1, 1, 9.5))
            conn.close()


class TestBackupRoundTrip(RecordTestCase):
    """The committed tier has to restore into a *rebuilt* record, not only into
    the one it came from — which is the whole scenario it exists for."""

    def test_identity_survives_renumbering(self):
        import backup
        first = self.make_title(title_original="Shawshank", year=1994)
        for namespace, value in (("kinopub", "56"), ("imdb", "tt0111161"),
                                 ("tmdb", "movie/278")):
            common.link_external(self.conn, first, namespace, value, "dump")

        out = Path(self.tmp.name) / "backup"
        out.mkdir()
        self.assertEqual(backup.dump_identity_clusters(self.conn, out / "identity.jsonl.gz"), 1)

        rebuilt = connect(Path(self.tmp.name) / "rebuilt.db")
        # Deliberately burn some ids so the new local id cannot coincide.
        for _ in range(5):
            resolve_title(rebuilt, ids={}, title_original="filler", year=1)
        spine, _ = resolve_title(rebuilt, ids={}, title_original="Shawshank", year=1994)
        common.link_external(rebuilt, spine, "imdb", "tt0111161", "dump")
        self.assertNotEqual(spine, first, "the test needs a different local id to be meaningful")

        total, added, unmatched = backup.restore_identity_clusters(
            rebuilt, out / "identity.jsonl.gz")
        self.assertEqual((total, unmatched), (1, 0))
        self.assertEqual(added, 2, "kinopub and tmdb should be re-linked")
        ids = dict(rebuilt.execute(
            "SELECT namespace, value FROM title_external_id WHERE title_id=?",
            (spine,)).fetchall())
        self.assertEqual(ids["tmdb"], "movie/278")
        rebuilt.close()

    def test_a_cluster_never_contains_a_local_id(self):
        import backup
        title = self.make_title()
        common.link_external(self.conn, title, "imdb", "tt1", "dump")
        out = Path(self.tmp.name) / "b"
        out.mkdir()
        backup.dump_identity_clusters(self.conn, out / "identity.jsonl.gz")
        with gzip.open(out / "identity.jsonl.gz", "rt") as stream:
            payload = json.loads(stream.readline())
        self.assertEqual(set(payload), {"ids"},
                         "a local autoincrement in the dump makes it unrestorable")


class TestArtworkCap(unittest.TestCase):
    """At most one poster per language, capped to ru/en/textless."""

    def rows(self, *specs):
        # (source, lang, width) -> a row shaped like the `image` table.
        return [{"source": s, "url": f"{s}-{l}-{w}", "lang": l, "width": w, "height": None,
                 "color_top": None, "color_bot": None} for s, l, w in specs]

    def test_at_most_three_survive(self):
        import document
        rows = self.rows(("tmdb", "ru", 500), ("tmdb", "en", 500), ("tmdb", None, 500),
                         ("tmdb", "fr", 500), ("tmdb", "ja", 500))
        self.assertEqual(len(document.cap_artwork(rows)), 3)

    def test_other_languages_are_dropped_not_folded_into_textless(self):
        import document
        rows = self.rows(("tmdb", "fr", 500))
        self.assertEqual(document.cap_artwork(rows), [])

    def test_order_is_ru_then_en_then_textless(self):
        import document
        rows = self.rows(("tmdb", None, 500), ("tmdb", "en", 500), ("tmdb", "ru", 500))
        langs = [a["lang"] for a in document.cap_artwork(rows)]
        self.assertEqual(langs, ["ru", "en", None])

    def test_the_higher_trust_source_wins_a_language_slot(self):
        import document
        # tvoe ranks above tmdb in the query ordering the real caller supplies;
        # cap_artwork must not re-sort, only take the first per language.
        rows = self.rows(("tvoe", "ru", 300), ("tmdb", "ru", 4000))
        picked = document.cap_artwork(rows)
        self.assertEqual(len(picked), 1)
        self.assertEqual(picked[0]["source"], "tvoe", "caller's ordering decides, not width")

    def test_a_missing_language_leaves_the_slot_empty_not_backfilled(self):
        import document
        rows = self.rows(("tmdb", "ru", 500))
        self.assertEqual([a["lang"] for a in document.cap_artwork(rows)], ["ru"])


class TestPushbrURL(unittest.TestCase):
    def test_matches_the_known_scheme(self):
        # md5("Тим Роббинс") — cross-checked against ActorImageProvider.swift's
        # own scheme (m.pushbr.com/actors/<md5(name)>.jpg) by hand.
        import hashlib
        name = "Тим Роббинс"
        expected = hashlib.md5(name.encode("utf-8")).hexdigest()
        self.assertEqual(common.pushbr_url(name), f"https://m.pushbr.com/actors/{expected}.jpg")

    def test_empty_name_has_no_url(self):
        self.assertIsNone(common.pushbr_url(""))
        self.assertIsNone(common.pushbr_url(None))
        self.assertIsNone(common.pushbr_url("   "))


class TestKinopoiskThinCoverage(RecordTestCase):
    """Whether the document trusts Kinopoisk-sourced cast identity for a title,
    or leads with TMDB instead. Two independent tells, either is enough."""

    def test_a_big_global_premiere_is_trusted_regardless_of_origin(self):
        import document
        title = self.make_title(title_original="A Foreign Blockbuster", year=2020)
        common.add_rating(self.conn, title, "imdb", 8.0, 500_000)
        common.add_rating(self.conn, title, "kinopoisk", 8.0, 400_000)
        self.conn.execute("INSERT INTO country(title_id,source,name) VALUES (?,'tmdb','Japan')",
                          (title,))
        self.assertFalse(document.kinopoisk_coverage_is_thin(self.conn, title))

    def test_a_small_foreign_title_with_no_ru_cis_link_is_thin(self):
        import document
        title = self.make_title(title_original="Obscure German Drama", year=2015)
        common.add_rating(self.conn, title, "imdb", 6.0, 300)
        self.conn.execute("INSERT INTO country(title_id,source,name) VALUES (?,'tmdb','Germany')",
                          (title,))
        self.assertTrue(document.kinopoisk_coverage_is_thin(self.conn, title))

    def test_ru_cis_origin_is_trusted_even_with_few_votes(self):
        import document
        title = self.make_title(title_original="Local Show", year=2015)
        common.add_rating(self.conn, title, "imdb", 6.0, 300)
        common.add_rating(self.conn, title, "kinopoisk", 6.0, 250)
        self.conn.execute("INSERT INTO country(title_id,source,name) VALUES (?,'tmdb','Россия')",
                          (title,))
        self.assertFalse(document.kinopoisk_coverage_is_thin(self.conn, title))

    def test_thin_when_kinopoisk_barely_rated_it_despite_ru_origin(self):
        import document
        title = self.make_title(title_original="Neglected Kinopoisk Entry", year=2015)
        common.add_rating(self.conn, title, "imdb", 7.0, 100_000)
        common.add_rating(self.conn, title, "kinopoisk", 7.0, 500)  # 0.5% of imdb
        self.conn.execute("INSERT INTO country(title_id,source,name) VALUES (?,'tmdb','Russia')",
                          (title,))
        self.assertTrue(document.kinopoisk_coverage_is_thin(self.conn, title))

    def test_no_evidence_at_all_defaults_to_thin(self):
        """No ratings, no country: nothing says this is RU/CIS or a hit, so the
        safer default is TMDB-first, not an assumed trust in Kinopoisk."""
        import document
        title = self.make_title()
        self.assertTrue(document.kinopoisk_coverage_is_thin(self.conn, title))


class TestPhotoCandidates(unittest.TestCase):
    def test_kinopoisk_family_leads_when_not_thin(self):
        import document
        photos = document.photo_candidates("Тим Роббинс", "https://st.kp.yandex.net/x.jpg",
                                           "kinopoisk_proxy", prefer_tmdb=False)
        self.assertTrue(photos[0].startswith("https://st.kp.yandex.net/"))
        self.assertTrue(photos[1].startswith("https://m.pushbr.com/"))

    def test_tmdb_leads_when_thin(self):
        import document
        photos = document.photo_candidates("Тим Роббинс", "https://image.tmdb.org/x.jpg",
                                           "tmdb", prefer_tmdb=True)
        self.assertTrue(photos[0].startswith("https://image.tmdb.org/"))
        self.assertTrue(photos[-1].startswith("https://m.pushbr.com/"))

    def test_no_name_no_stored_photo_is_an_empty_list_not_a_crash(self):
        import document
        self.assertEqual(document.photo_candidates(None, None, None, prefer_tmdb=False), [])

    def test_never_duplicates_a_url_across_candidates(self):
        import document
        photos = document.photo_candidates("X", "https://image.tmdb.org/x.jpg", "tmdb",
                                           prefer_tmdb=True)
        self.assertEqual(len(photos), len(set(photos)))


class TestCreditMerge(RecordTestCase):
    """One row per person in the document, whatever sources contributed."""

    def test_two_sources_for_one_person_merge_into_one_credit(self):
        import document
        title = self.make_title()
        person = resolve_person(self.conn, name_ru="Тим Роббинс", name_en="Tim Robbins")
        self.conn.execute(
            "INSERT INTO title_credit(title_id,person_id,department,character,ord,"
            "episode_count,source) VALUES (?,?,'actor','Andy Dufresne',0,NULL,'tmdb')",
            (title, person))
        self.conn.execute(
            "INSERT INTO title_credit(title_id,person_id,department,character,ord,"
            "episode_count,source) VALUES (?,?,'actor',NULL,5,NULL,'kinopoisk_proxy')",
            (title, person))
        credits = document.build_credits(self.conn, title)
        self.assertEqual(len(credits), 1)
        self.assertEqual(credits[0]["character"], "Andy Dufresne")
        self.assertEqual(credits[0]["ord"], 0, "TMDB's true billing order must win over a stand-in")
        self.assertEqual(set(credits[0]["sources"]), {"tmdb", "kinopoisk_proxy"})

    def test_multiple_departments_on_one_person_are_all_kept(self):
        import document
        title = self.make_title()
        person = resolve_person(self.conn, name_ru="Фрэнк Дарабонт")
        for department in ("director", "screenwriter"):
            self.conn.execute(
                "INSERT INTO title_credit(title_id,person_id,department,character,ord,"
                "episode_count,source) VALUES (?,?,?,NULL,NULL,NULL,'kinopoisk_proxy')",
                (title, person, department))
        credits = document.build_credits(self.conn, title)
        self.assertEqual(set(credits[0]["departments"]), {"director", "screenwriter"})

    def test_kinopoisk_character_text_is_preferred_when_both_exist(self):
        import document
        title = self.make_title()
        person = resolve_person(self.conn, name_ru="Актёр")
        self.conn.execute(
            "INSERT INTO title_credit(title_id,person_id,department,character,ord,"
            "episode_count,source) VALUES (?,?,'actor','English Name',0,NULL,'tmdb')",
            (title, person))
        self.conn.execute(
            "INSERT INTO title_credit(title_id,person_id,department,character,ord,"
            "episode_count,source) VALUES (?,?,'actor','Русское имя',1,NULL,'kinopoisk_proxy')",
            (title, person))
        credits = document.build_credits(self.conn, title)
        self.assertEqual(credits[0]["character"], "Русское имя")


class TestTMDBCreditLanguageLabeling(unittest.TestCase):
    """The bug: a ru-RU-localized TMDB name was stored as `name_en`, so it
    could never join against Kinopoisk's identical Russian spelling — same
    person, same script, split into two rows by a mislabeled column."""

    def test_a_ru_fetch_labels_the_localized_name_as_russian(self):
        import fetch_tmdb
        person = {"name": "Тим Роббинс", "original_name": "Tim Robbins"}
        name_ru, name_en = fetch_tmdb._credit_names(person, "ru-RU")
        self.assertEqual(name_ru, "Тим Роббинс")
        self.assertEqual(name_en, "Tim Robbins")

    def test_an_en_fetch_labels_it_english_instead(self):
        import fetch_tmdb
        person = {"name": "Tim Robbins", "original_name": "Tim Robbins"}
        name_ru, name_en = fetch_tmdb._credit_names(person, "en-US")
        self.assertIsNone(name_ru)
        self.assertEqual(name_en, "Tim Robbins")

    def test_identical_localized_and_original_names_do_not_duplicate(self):
        import fetch_tmdb
        # Foreign-original credits where TMDB has no Russian translation yet —
        # `name` and `original_name` are the same string.
        person = {"name": "Rémi Bezançon", "original_name": "Rémi Bezançon"}
        name_ru, name_en = fetch_tmdb._credit_names(person, "ru-RU")
        self.assertEqual(name_ru, "Rémi Bezançon")
        self.assertIsNone(name_en, "must not duplicate the same string into both columns")

    def test_the_join_actually_works_end_to_end(self):
        """The point of the whole fix: TMDB's ru-RU name must resolve to the
        SAME person row Kinopoisk already created under name_ru."""
        with tempfile.TemporaryDirectory() as tmp:
            conn = connect(Path(tmp) / "t.db")
            kinopoisk_person = resolve_person(conn, name_ru="Тим Роббинс",
                                              name_en="Tim Robbins")
            name_ru, name_en = __import__("fetch_tmdb")._credit_names(
                {"name": "Тим Роббинс", "original_name": "Tim Robbins"}, "ru-RU")
            tmdb_person = resolve_person(conn, name_ru=name_ru, name_en=name_en,
                                         ids={"tmdb": 12345})
            self.assertEqual(kinopoisk_person, tmdb_person,
                            "same person, same script — must be one row, not two")
            conn.close()

if __name__ == "__main__":
    unittest.main(verbosity=2)
