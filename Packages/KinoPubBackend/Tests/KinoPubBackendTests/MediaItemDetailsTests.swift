//
//  MediaItemDetailsTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class MediaItemDetailsTests: XCTestCase {

  private func item(rating: Int = 0,
                    ratingVotes: Int = 0,
                    ratingPercentage: Double = 0,
                    cast: String = "",
                    director: String = "",
                    countries: [Country] = [],
                    seasons: [Season]? = nil,
                    duration: Duration = Duration(average: 0, total: 0)) -> MediaItem {
    let mock = MediaItem.mock()
    return MediaItem(id: mock.id, type: mock.type, subtype: mock.subtype, title: mock.title,
                     year: mock.year, cast: cast, director: director, genres: mock.genres,
                     countries: countries, voice: mock.voice, duration: duration,
                     langs: mock.langs, quality: mock.quality, plot: mock.plot, imdb: mock.imdb,
                     imdbRating: mock.imdbRating, imdbVotes: mock.imdbVotes, kinopoisk: mock.kinopoisk,
                     kinopoiskRating: mock.kinopoiskRating, kinopoiskVotes: mock.kinopoiskVotes,
                     rating: rating, ratingVotes: ratingVotes,
                     ratingPercentage: ratingPercentage, views: mock.views,
                     comments: mock.comments, posters: mock.posters, trailer: mock.trailer,
                     finished: mock.finished, advert: mock.advert, poorQuality: mock.poorQuality,
                     createdAt: mock.createdAt, updatedAt: mock.updatedAt,
                     inWatchlist: mock.inWatchlist, subscribed: mock.subscribed, ac3: mock.ac3,
                     bookmarks: mock.bookmarks, seasons: seasons, videos: nil)
  }

  // MARK: - kino.pub community votes

  /// Real API values: 36 net over 328 votes. Likes and dislikes recover exactly, and
  /// 182/328 is the 55% the API reports.
  func testLikesAndDislikesRecoverFromNetAndTotal() {
    let votes = item(rating: 36, ratingVotes: 328, ratingPercentage: 55).communityVotes
    XCTAssertEqual(votes?.likes, 182)
    XCTAssertEqual(votes?.dislikes, 146)
  }

  /// A net score below zero is normal — more dislikes than likes.
  func testNegativeNetMeansMoreDislikes() {
    let votes = item(rating: -5, ratingVotes: 25, ratingPercentage: 40).communityVotes
    XCTAssertEqual(votes?.likes, 10)
    XCTAssertEqual(votes?.dislikes, 15)
  }

  func testSmallTallyStillSplitsCorrectly() {
    let votes = item(rating: 2, ratingVotes: 4, ratingPercentage: 75).communityVotes
    XCTAssertEqual(votes?.likes, 3)
    XCTAssertEqual(votes?.dislikes, 1)
  }

  func testUnvotedItemHasNoTally() {
    XCTAssertNil(item(ratingVotes: 0).communityVotes)
  }

  /// Nonsense input must not produce a negative count on screen.
  func testInconsistentCountsAreRejected() {
    XCTAssertNil(item(rating: 500, ratingVotes: 10).communityVotes)
  }

  // MARK: - Names

  func testCastSplitsOnCommasAndTrims() {
    let names = item(cast: "Октавия Спенсер, Ханна Уэддингхэм ,Эд Скрейн").castMembers
    XCTAssertEqual(names, ["Октавия Спенсер", "Ханна Уэддингхэм", "Эд Скрейн"])
  }

  func testEmptyCastProducesNoNames() {
    XCTAssertTrue(item(cast: "").castMembers.isEmpty)
    XCTAssertTrue(item(director: " , ").directorNames.isEmpty)
  }

  /// microiptv shows one; the API returns them all.
  func testEveryCountryIsKept() {
    let names = item(countries: [Country(id: 1, title: "США"),
                                 Country(id: 2, title: "Канада")]).countryNames
    XCTAssertEqual(names, ["США", "Канада"])
  }

  // MARK: - Duration

  func testFilmUsesItsTotalRuntime() {
    let film = item(duration: Duration(average: 0, total: 108 * 60))
    XCTAssertEqual(film.displayDuration, "1 h 48 min")
  }

  /// A series' `total` is the sum of every episode, which reads as nonsense as *the*
  /// runtime — but is worth showing on its own line.
  func testSeriesUsesThePerEpisodeAverage() {
    let series = seriesItem(duration: Duration(average: 51 * 60, total: 21600))
    XCTAssertEqual(series.displayDuration, "51 min")
  }

  func testSeriesAlsoReportsItsTotalRuntime() {
    let series = seriesItem(duration: Duration(average: 51 * 60, total: 21600))
    XCTAssertEqual(series.totalDurationDisplay, "6 h")
  }

  func testFilmHasNoSeparateTotal() {
    XCTAssertNil(item(duration: Duration(average: 0, total: 108 * 60)).totalDurationDisplay)
  }

  private func seriesItem(duration: Duration) -> MediaItem {
    let season = Season(id: 1, title: "S1", number: 1,
                        watching: SeasonWatching(status: 0), episodes: [])
    return item(seasons: [season], duration: duration)
  }

  // MARK: - Language names

  func testKnownCodesResolveToNames() {
    XCTAssertEqual(LanguageNames.name(for: "rus"), "Russian")
    XCTAssertEqual(LanguageNames.name(for: "eng"), "English")
  }

  func testUnknownCodeFallsBackToItself() {
    XCTAssertEqual(LanguageNames.name(for: "zzz"), "zzz")
  }

  func testEmptyCodeProducesEmptyName() {
    XCTAssertEqual(LanguageNames.name(for: "  "), "")
  }
}
