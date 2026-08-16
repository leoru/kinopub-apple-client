//
//  MediaItemVariantsTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

/// The Lego Movie as `/v1/items?director=Фил Лорд` actually answers it: #9072 is the
/// 3D encoding, #7319 the flat one, both kinopoisk 471644 / imdb 1490017.
final class MediaItemVariantsTests: XCTestCase {

  private func item(id: Int,
                    type: String = "movie",
                    title: String,
                    year: Int,
                    kinopoisk: Int? = nil,
                    imdb: Int? = nil,
                    kinopoiskRating: Double? = nil,
                    imdbRating: Double? = nil,
                    ratingPercentage: Double = 0,
                    quality: Int = 1080,
                    langs: Int = 1,
                    views: Int = 0) throws -> MediaItem {
    var json: [String: Any] = [
      "id": id,
      "type": type,
      "subtype": "",
      "title": title,
      "year": year,
      "quality": quality,
      "langs": langs,
      "views": views,
      "rating_percentage": ratingPercentage,
      "duration": ["average": 0, "total": 0],
      "posters": ["small": "", "medium": "", "big": "", "wide": ""]
    ]
    if let kinopoisk { json["kinopoisk"] = kinopoisk }
    if let imdb { json["imdb"] = imdb }
    if let kinopoiskRating { json["kinopoisk_rating"] = kinopoiskRating }
    if let imdbRating { json["imdb_rating"] = imdbRating }
    let data = try JSONSerialization.data(withJSONObject: json)
    return try JSONDecoder().decode(MediaItem.self, from: data)
  }

  private func lego3D() throws -> MediaItem {
    try item(id: 9072, type: "3d", title: "Лего. Фильм 3D / The Lego Movie", year: 2014,
             kinopoisk: 471644, imdb: 1490017, kinopoiskRating: 7.2, imdbRating: 7.7,
             ratingPercentage: 78, quality: 1080, langs: 4, views: 566)
  }

  private func legoFlat() throws -> MediaItem {
    try item(id: 7319, title: "ЛЕГО Фильм / The Lego Movie", year: 2014,
             kinopoisk: 471644, imdb: 1490017, kinopoiskRating: 7.2, imdbRating: 7.7,
             ratingPercentage: 95, quality: 2160, langs: 9, views: 91624)
  }

  // MARK: - Film identity

  func testCopiesOfOneFilmShareIdentity() throws {
    XCTAssertEqual(try lego3D().filmIdentity, try legoFlat().filmIdentity)
  }

  /// Without external ids the title carries it: "3D", case and punctuation differ
  /// between the two entries and none of them may split the film in two.
  func testTitleFallbackIgnores3DCaseAndPunctuation() throws {
    let threeD = try item(id: 1, type: "3d", title: "Лего. Фильм 3D / The Lego Movie", year: 2014)
    let flat = try item(id: 2, title: "ЛЕГО Фильм / The Lego Movie", year: 2014)
    XCTAssertEqual(threeD.filmIdentity, flat.filmIdentity)
  }

  /// Two different films must not collapse just because neither has an external id.
  func testDifferentFilmsKeepDifferentIdentities() throws {
    let first = try item(id: 1, title: "Мачо и ботан / 21 Jump Street", year: 2012)
    let second = try item(id: 2, title: "Мачо и ботан 2 / 22 Jump Street", year: 2014)
    XCTAssertNotEqual(first.filmIdentity, second.filmIdentity)
  }

  // MARK: - Collapsing

  func testKeepsFlatCopyByDefault() throws {
    let collapsed = [try lego3D(), try legoFlat()].collapsingFilmVariants()
    XCTAssertEqual(collapsed.map(\.id), [7319])
  }

  func testKeeps3DCopyForA3DPage() throws {
    let collapsed = [try legoFlat(), try lego3D()].collapsingFilmVariants(preferring3D: true)
    XCTAssertEqual(collapsed.map(\.id), [9072])
  }

  /// The surviving copy takes the position of the first one seen, so a rating-ordered
  /// answer stays rating-ordered after collapsing.
  func testCollapsingKeepsIncomingOrder() throws {
    let hailMary = try item(id: 122242, title: "Проект «Конец света» / Project Hail Mary",
                            year: 2026, kinopoisk: 1382256)
    let jumpStreet = try item(id: 8004, title: "Мачо и ботан 2 / 22 Jump Street",
                              year: 2014, kinopoisk: 672899)
    let collapsed = [hailMary, try lego3D(), try legoFlat(), jumpStreet].collapsingFilmVariants()
    XCTAssertEqual(collapsed.map(\.id), [122242, 7319, 8004])
  }

  /// Same film, same file: the copy people actually watch represents it.
  func testEquallyGoodCopiesAreSplitByViews() throws {
    let watched = try item(id: 1, title: "Тест / Test", year: 2020, kinopoisk: 1, views: 90_000)
    let ignored = try item(id: 2, title: "Тест / Test", year: 2020, kinopoisk: 1, views: 100)
    XCTAssertEqual([ignored, watched].collapsingFilmVariants().map(\.id), [1])
  }

  /// Same film, both copies without ids and with the same quality — one card, whichever
  /// it is, and no crash on the tie.
  func testCollapsesIdenticalCopies() throws {
    let first = try item(id: 1, title: "Тест / Test", year: 2020)
    let second = try item(id: 2, title: "Тест / Test", year: 2020)
    XCTAssertEqual([first, second].collapsingFilmVariants().count, 1)
  }

  // MARK: - Ordering

  /// Same year: the more watched film leads. A high score from a handful of votes must
  /// not lift a no-name over a film everybody here has seen.
  func testSortsNewestFirstThenByViews() throws {
    let old = try item(id: 1, title: "A", year: 2012, views: 58_113)
    let new = try item(id: 2, title: "B", year: 2026, views: 0)
    let watched2014 = try item(id: 3, title: "C", year: 2014,
                               kinopoiskRating: 6.7, views: 38_464)
    let noName2014 = try item(id: 4, title: "D", year: 2014,
                              kinopoiskRating: 9.9, views: 566)
    let sorted = [noName2014, old, watched2014, new].sortedNewestFirst()
    XCTAssertEqual(sorted.map(\.id), [2, 3, 4, 1])
  }

  // MARK: - 3D detection

  func testThreeDFromTypeAndSubtype() throws {
    XCTAssertTrue(try lego3D().is3D)
    XCTAssertFalse(try legoFlat().is3D)
  }
}
