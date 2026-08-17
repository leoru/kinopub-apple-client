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
    XCTAssertEqual(profile(type: "serial", genres: [(2, "Аниме")]).kind, .anime)
    XCTAssertEqual(profile(type: "movie", genres: [(2, "Anime")]).kind, .anime)
  }

  /// A cartoon is not an anime — it keeps the default treatment until we decide
  /// otherwise.
  func testCartoonStaysFiction() {
    XCTAssertEqual(profile(type: "movie", genres: [(23, "Мультфильм")]).kind, .fiction)
  }

  // MARK: - What each kind shows

  func testOnlyFictionGetsFacesAndAStarringLine() {
    XCTAssertTrue(MediaPresentationProfile(kind: .fiction).showsCastPortraits)
    XCTAssertTrue(MediaPresentationProfile(kind: .fiction).showsHeroCastLine)
    for kind in [MediaPresentationKind.documentary, .performance, .anime] {
      XCTAssertFalse(MediaPresentationProfile(kind: kind).showsCastPortraits, "\(kind)")
      XCTAssertFalse(MediaPresentationProfile(kind: kind).showsHeroCastLine, "\(kind)")
    }
  }

  func testCreditsLabelFollowsTheTreatment() {
    XCTAssertEqual(MediaPresentationProfile(kind: .fiction).creditsTitleKey, "Cast & Crew")
    XCTAssertEqual(MediaPresentationProfile(kind: .performance).creditsTitleKey, "MediaItem_Credits")
  }

  // MARK: - Reading it off an item

  func testItemExposesItsProfile() {
    XCTAssertEqual(MediaItem.mock(id: 1, type: "concert").presentation.kind, .performance)
    XCTAssertEqual(MediaItem.mock(id: 2, type: "movie").presentation.kind, .fiction)
  }
}
