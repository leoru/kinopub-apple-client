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

import json
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
