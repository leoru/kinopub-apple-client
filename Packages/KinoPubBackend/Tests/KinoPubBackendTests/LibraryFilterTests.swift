//
//  LibraryFilterTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class LibraryFilterTests: XCTestCase {

  private func params(_ filter: LibraryFilter, page: Int? = nil) -> [String: String] {
    let raw = ItemsRequest(filter: filter, page: page).parameters ?? [:]
    return raw.mapValues { "\($0)" }
  }

  // MARK: - Sort values

  /// `-` prefixes descending. Title is the one sort that reads better ascending.
  func testSortValues() {
    XCTAssertEqual(MediaSortOrder.recentlyAdded.apiValue, "-created")
    XCTAssertEqual(MediaSortOrder.recentlyUpdated.apiValue, "-updated")
    XCTAssertEqual(MediaSortOrder.views.apiValue, "-views")
    XCTAssertEqual(MediaSortOrder.title.apiValue, "title")
    XCTAssertEqual(MediaSortOrder.year.apiValue, "-year")
  }

  /// Undocumented, but the service accepts both and orders correctly — checked
  /// against live responses before they were offered in the UI.
  func testRatingSortsUseTheUndocumentedFields() {
    XCTAssertEqual(MediaSortOrder.kinopoiskRating.apiValue, "-kinopoisk_rating")
    XCTAssertEqual(MediaSortOrder.imdbRating.apiValue, "-imdb_rating")
  }

  func testEverySortIsOffered() {
    XCTAssertEqual(MediaSortOrder.allCases.count, 7)
  }

  // MARK: - Request building

  func testDefaultFilterOnlySendsTheSort() {
    XCTAssertEqual(params(LibraryFilter()), ["sort": "-created"])
  }

  func testFiltersMapToTheirParameters() {
    let filter = LibraryFilter(contentType: .serial,
                               sort: .views,
                               genreID: 25,
                               countryID: 10,
                               years: YearRange(from: 1990, to: 1999),
                               period: .month)

    XCTAssertEqual(params(filter, page: 3), [
      "sort": "-views",
      "type": "serial",
      "genre": "25",
      "country": "10",
      "year": "1990-1999",
      "period": "month",
      "page": "3"
    ])
  }

  func testPeriodIsSentServerSide() {
    XCTAssertEqual(params(LibraryFilter(period: .week))["period"], "week")
    XCTAssertNil(params(LibraryFilter())["period"])
  }

  /// "Any" must drop the parameter, not send an empty one.
  func testUnsetFiltersAreOmitted() {
    let keys = Set(params(LibraryFilter(contentType: .movie)).keys)
    XCTAssertEqual(keys, ["sort", "type"])
  }

  func testRequestTargetsTheItemsEndpoint() {
    let request = ItemsRequest(filter: LibraryFilter())
    XCTAssertEqual(request.path, "/v1/items")
    XCTAssertEqual(request.method, "GET")
  }

  /// Regression: this pointed at /v1/countries, which would have filled the genre
  /// picker with country names.
  func testGenresRequestTargetsGenres() {
    XCTAssertEqual(GenresRequest().path, "/v1/genres")
    XCTAssertNil(GenresRequest().parameters)
    XCTAssertEqual(GenresRequest(contentType: .movie).parameters?["type"] as? String, "movie")
  }

  // MARK: - Year ranges

  func testDecadesRunNewestFirstFromTheCurrentOne() {
    let decades = YearRange.decades(upTo: 2026)
    XCTAssertEqual(decades.first, YearRange(from: 2020, to: 2029))
    XCTAssertEqual(decades.last, YearRange(from: 1950, to: 1959))
    XCTAssertEqual(decades[1], YearRange(from: 2010, to: 2019))
  }

  func testYearRangeFormatsForTheAPI() {
    XCTAssertEqual(YearRange(from: 2000, to: 2009).apiValue, "2000-2009")
  }

  // MARK: - Active state

  func testDefaultFilterIsNotConsideredActive() {
    XCTAssertFalse(LibraryFilter().hasActiveFilters)
  }

  /// Sorting is always set, so changing it alone must not light up "Clear".
  func testSortAloneIsNotAnActiveFilter() {
    XCTAssertFalse(LibraryFilter(sort: .imdbRating).hasActiveFilters)
  }

  func testAnyRealFilterCountsAsActive() {
    XCTAssertTrue(LibraryFilter(contentType: .movie).hasActiveFilters)
    XCTAssertTrue(LibraryFilter(genreID: 1).hasActiveFilters)
    XCTAssertTrue(LibraryFilter(countryID: 1).hasActiveFilters)
    XCTAssertTrue(LibraryFilter(years: YearRange(from: 2000, to: 2009)).hasActiveFilters)
    XCTAssertTrue(LibraryFilter(period: .day).hasActiveFilters)
    XCTAssertTrue(LibraryFilter(want4K: true).hasActiveFilters)
    XCTAssertTrue(LibraryFilter(kinopoiskMin: 7).hasActiveFilters)
  }

  func testGenresAndCountriesOptIntoDiskCache() {
    XCTAssertEqual(GenresRequest().cachePolicy.ttl, 365 * 86_400)
    XCTAssertTrue(GenresRequest().cachePolicy.persistsToDisk)
    XCTAssertEqual(CountriesRequest().cachePolicy.ttl, 365 * 86_400)
    XCTAssertTrue(CountriesRequest().cachePolicy.persistsToDisk)
  }

  // MARK: - Genre decoding

  /// The API sends `"id": 25`; the model previously declared it `String`, so every
  /// genre response failed to decode and the picker was always empty.
  func testGenreDecodesAnIntegerID() throws {
    let json = #"{"items":[{"id":25,"type":"movie","title":"Аниме"}]}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ArrayData<MediaGenre>.self, from: json)

    XCTAssertEqual(decoded.items.first?.id, 25)
    XCTAssertEqual(decoded.items.first?.title, "Аниме")
    XCTAssertEqual(decoded.items.first?.type, .movie)
  }
}
