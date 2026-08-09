import XCTest
@testable import KinoPubUI

final class RatingTests: XCTestCase {

  func testAveragesBothSources() {
    XCTAssertEqual(Rating(imdb: 8.0, kinopoisk: 7.0)?.value ?? 0, 7.5, accuracy: 0.001)
  }

  /// 6.0 from 4,867 voters next to 1.0 from 7 is a 6.0 title. A plain mean printed 3.5.
  func testWeightsSourcesByVoteCount() {
    let rating = Rating(imdb: 6.0, imdbVotes: 4_867, kinopoisk: 1.0, kinopoiskVotes: 7)
    XCTAssertEqual(rating?.value ?? 0, 5.993, accuracy: 0.001)
    XCTAssertEqual(rating?.formatted, "6.0")
  }

  /// A source that reports no count still counts — as one vote, so it cannot outweigh
  /// a real audience, and two countless sources still average evenly.
  func testMissingVoteCountsWeighAsOne() {
    XCTAssertEqual(Rating(imdb: 9.0, imdbVotes: 1_000, kinopoisk: 4.0)?.value ?? 0,
                   8.995, accuracy: 0.001)
    XCTAssertEqual(Rating(imdb: 8.0, kinopoisk: 7.0)?.value ?? 0, 7.5, accuracy: 0.001)
  }

  /// Votes on an unrated source are not a score: they must not enter the average.
  func testVotesWithoutAScoreAreIgnored() {
    XCTAssertEqual(Rating(imdb: 7.4, imdbVotes: 300, kinopoisk: 0, kinopoiskVotes: 90_000)?.value ?? 0,
                   7.4, accuracy: 0.001)
  }

  func testUsesTheOnlyRatedSource() {
    XCTAssertEqual(Rating(imdb: 7.4, kinopoisk: nil)?.value ?? 0, 7.4, accuracy: 0.001)
    XCTAssertEqual(Rating(imdb: nil, kinopoisk: 6.2)?.value ?? 0, 6.2, accuracy: 0.001)
  }

  /// The API sends 0 for "not rated", so it must not drag the average down.
  func testZeroCountsAsUnrated() {
    XCTAssertEqual(Rating(imdb: 0, kinopoisk: 9.0)?.value ?? 0, 9.0, accuracy: 0.001)
    XCTAssertEqual(Rating(imdb: 9.0, kinopoisk: 0)?.value ?? 0, 9.0, accuracy: 0.001)
  }

  func testNoRatingWhenBothAreMissingOrZero() {
    XCTAssertNil(Rating(imdb: nil, kinopoisk: nil))
    XCTAssertNil(Rating(imdb: 0, kinopoisk: 0))
  }

  func testTierBoundaries() {
    XCTAssertEqual(Rating(imdb: 8.0, kinopoisk: nil)?.tier, .awarded)
    XCTAssertEqual(Rating(imdb: 7.94, kinopoisk: nil)?.tier, .good)
    XCTAssertEqual(Rating(imdb: 7.0, kinopoisk: nil)?.tier, .good)
    XCTAssertEqual(Rating(imdb: 6.94, kinopoisk: nil)?.tier, .average)
    XCTAssertEqual(Rating(imdb: 6.0, kinopoisk: nil)?.tier, .average)
    XCTAssertEqual(Rating(imdb: 5.94, kinopoisk: nil)?.tier, .poor)
  }

  /// Whatever number is on screen decides the colour — a 7.95 reads "8.0", so it is
  /// tiered as 8.0 rather than showing a gold-adjacent number in green.
  func testTierFollowsTheDisplayedValue() {
    let rating = Rating(imdb: 7.95, kinopoisk: nil)
    XCTAssertEqual(rating?.formatted, "8.0")
    XCTAssertEqual(rating?.tier, .awarded)
  }

  func testOnlyTheTopTierGetsWings() {
    XCTAssertTrue(Rating(imdb: 8.5, kinopoisk: nil)!.tier.showsWings)
    XCTAssertFalse(Rating(imdb: 7.5, kinopoisk: nil)!.tier.showsWings)
  }

  func testFormattedToOneDecimal() {
    XCTAssertEqual(Rating(imdb: 8.25, kinopoisk: 8.25)?.formatted, "8.3")
    XCTAssertEqual(Rating(imdb: 7.0, kinopoisk: nil)?.formatted, "7.0")
  }
}
