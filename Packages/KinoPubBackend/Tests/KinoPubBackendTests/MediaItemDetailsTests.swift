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
                     bookmarks: mock.bookmarks, seasons: seasons, videos: nil,
                     skeleton: mock.skeleton)
  }

  // MARK: - kino.pub rating

  /// Verified against the live API: 55% over 328 votes displays as 5.5. The bare
  /// `rating` field is the net vote count and goes negative, so it is never shown.
  func testKinopubRatingComesFromThePercentage() {
    let value = item(rating: 36, ratingVotes: 328, ratingPercentage: 55).kinopubRating
    XCTAssertEqual(value ?? 0, 5.5, accuracy: 0.001)
  }

  func testNegativeNetRatingStillProducesAPositiveScore() {
    let value = item(rating: -5, ratingVotes: 25, ratingPercentage: 40).kinopubRating
    XCTAssertEqual(value ?? 0, 4.0, accuracy: 0.001)
  }

  func testUnratedItemHasNoScore() {
    XCTAssertNil(item(ratingVotes: 0, ratingPercentage: 0).kinopubRating)
    XCTAssertNil(item(ratingVotes: 10, ratingPercentage: 0).kinopubRating)
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

  /// A series' `total` is the sum of every episode, which reads as nonsense.
  func testSeriesUsesThePerEpisodeAverage() {
    let season = Season(id: 1, title: "S1", number: 1,
                        watching: SeasonWatching(status: 0), episodes: [])
    let series = item(seasons: [season], duration: Duration(average: 51 * 60, total: 21600))
    XCTAssertEqual(series.displayDuration, "51 min")
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
