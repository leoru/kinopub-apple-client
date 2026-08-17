//
//  MediaPresentationTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class MediaPresentationTests: XCTestCase {

  private func profile(type: String = "movie", genres: [(Int, String)] = []) -> MediaPresentationProfile {
    MediaPresentationProfile(
      type: type,
      genres: genres.map { TypeClass(id: $0.0, title: $0.1, shortTitle: nil) }
    )
  }

  // MARK: - Kinds

  func testFilmsAndSeriesAreFiction() {
    XCTAssertEqual(profile(type: "movie", genres: [(1, "Комедия")]).kind, .fiction)
    XCTAssertEqual(profile(type: "serial").kind, .fiction)
    XCTAssertEqual(profile(type: "3d").kind, .fiction)
  }

  func testDocumentaryTypes() {
    XCTAssertEqual(profile(type: "documovie").kind, .documentary)
    XCTAssertEqual(profile(type: "docuserial").kind, .documentary)
  }

  /// A documentary filed as a plain movie is only knowable from the genre.
  func testDocumentaryGenreOnAPlainMovie() {
    XCTAssertEqual(profile(type: "movie", genres: [(9, "Документальный")]).kind, .documentary)
    XCTAssertEqual(profile(type: "movie", genres: [(9, "Documentary")]).kind, .documentary)
  }

  func testConcertType() {
    XCTAssertEqual(profile(type: "concert").kind, .performance)
  }

  /// Genre 101 — the one id kino.pub confirmed.
  func testStandupGenreByID() {
    XCTAssertEqual(profile(type: "movie", genres: [(101, "Стендап")]).kind, .performance)
    XCTAssertEqual(profile(type: "movie", genres: [(101, "")]).kind, .performance)
  }

  func testStandupGenreByTitle() {
    XCTAssertEqual(profile(type: "movie", genres: [(555, "Стенд-ап")]).kind, .performance)
    XCTAssertEqual(profile(type: "movie", genres: [(555, "Stand-Up")]).kind, .performance)
  }

  func testAnimeGenre() {
    XCTAssertEqual(profile(type: "serial", genres: [(2, "Аниме")]).kind, .animation)
    XCTAssertEqual(profile(type: "movie", genres: [(2, "Anime")]).kind, .animation)
  }

  /// Genre 23 is "Мультфильм" — a cartoon gets the same treatment as an anime, and it
  /// arrives buried in a list of ordinary genres.
  func testCartoonGenreByID() {
    let genres = [(2, "Боевик"), (5, "Фэнтези"), (6, "Семейный"),
                  (8, "Приключения"), (13, "Детектив"), (23, "Мультфильм")]
    XCTAssertEqual(profile(type: "movie", genres: genres).kind, .animation)
  }

  func testTVShowType() {
    XCTAssertEqual(profile(type: "tvshow").kind, .show)
  }

  // MARK: - What each kind shows

  func testOnlyFictionGetsFacesAndAStarringLine() {
    XCTAssertTrue(MediaPresentationProfile(kind: .fiction).showsCastPortraits)
    XCTAssertTrue(MediaPresentationProfile(kind: .fiction).showsHeroCastLine)
    for kind in [MediaPresentationKind.documentary, .performance, .animation, .show] {
      XCTAssertFalse(MediaPresentationProfile(kind: kind).showsCastPortraits, "\(kind)")
      XCTAssertFalse(MediaPresentationProfile(kind: kind).showsHeroCastLine, "\(kind)")
    }
  }

  // MARK: - Author: director or creator

  func testEpisodicAndDocumentaryTitlesCreditCreators() {
    for type in ["serial", "docuserial", "tvshow", "documovie"] {
      XCTAssertEqual(profile(type: type).authorRole, .creator, type)
      XCTAssertEqual(profile(type: type).authorCaptionKey, "MediaItem_Creators", type)
    }
    for type in ["movie", "3d", "concert"] {
      XCTAssertEqual(profile(type: type).authorRole, .director, type)
      XCTAssertEqual(profile(type: type).authorCaptionKey, "Director", type)
    }
  }

  func testAuthorShelfTitleFollowsRoleAndCount() {
    let film = profile(type: "movie")
    XCTAssertEqual(film.authorShelfTitleKey(count: 1), "MediaItem_MoreByDirector")
    XCTAssertEqual(film.authorShelfTitleKey(count: 2), "MediaItem_MoreByDirectors")

    let series = profile(type: "serial")
    XCTAssertEqual(series.authorShelfTitleKey(count: 1), "MediaItem_MoreByCreator")
    XCTAssertEqual(series.authorShelfTitleKey(count: 3), "MediaItem_MoreByCreators")
  }

  /// A concert's or a stand-up set's "director" is a TV credit nobody follows.
  func testPerformancesGetNoAuthorShelf() {
    XCTAssertFalse(profile(type: "concert").showsAuthorShelf)
    XCTAssertFalse(profile(type: "movie", genres: [(101, "Стендап")]).showsAuthorShelf)
    for type in ["movie", "serial", "documovie", "tvshow"] {
      XCTAssertTrue(profile(type: type).showsAuthorShelf, type)
    }
    XCTAssertTrue(profile(type: "movie", genres: [(23, "Мультфильм")]).showsAuthorShelf)
  }

  // MARK: - Reading it off an item

  func testItemExposesItsProfile() {
    XCTAssertEqual(MediaItem.mock(id: 1, type: "concert").presentation.kind, .performance)
    XCTAssertEqual(MediaItem.mock(id: 2, type: "movie").presentation.kind, .fiction)
  }
}

// MARK: - Several credited names as one query

final class MediaPersonGroupTests: XCTestCase {

  /// A comma is `/v1/items`' OR on `director` / `cast`, so two directors ask for
  /// everything either of them made.
  func testGroupJoinsNamesForTheQuery() throws {
    let group = try XCTUnwrap(MediaPerson.group(names: ["Фил Лорд", "Кристофер Миллер"],
                                                role: .director))
    XCTAssertEqual(group.name, "Фил Лорд,Кристофер Миллер")
    XCTAssertTrue(group.isGroup)
    XCTAssertEqual(group.names, ["Фил Лорд", "Кристофер Миллер"])
  }

  func testSingleNameIsNotAGroup() throws {
    let one = try XCTUnwrap(MediaPerson.group(names: ["Джеймс Ганн"], role: .director))
    XCTAssertFalse(one.isGroup)
    XCTAssertEqual(one.names, ["Джеймс Ганн"])
    XCTAssertEqual(one, MediaPerson(name: "Джеймс Ганн", role: .director))
  }

  func testEmptyNamesProduceNoQuery() {
    XCTAssertNil(MediaPerson.group(names: [], role: .director))
    XCTAssertNil(MediaPerson.group(names: ["", "  "], role: .director))
  }
}
