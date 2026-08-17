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
    XCTAssertEqual(profile(type: "concert").kind, .concert)
  }

  /// Genre 101 — the one id kino.pub confirmed.
  func testStandupGenreByID() {
    XCTAssertEqual(profile(type: "movie", genres: [(101, "Стендап")]).kind, .standup)
    XCTAssertEqual(profile(type: "movie", genres: [(101, "")]).kind, .standup)
  }

  func testStandupGenreByTitle() {
    XCTAssertEqual(profile(type: "movie", genres: [(555, "Стенд-ап")]).kind, .standup)
    XCTAssertEqual(profile(type: "movie", genres: [(555, "Stand-Up")]).kind, .standup)
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
    for kind in [MediaPresentationKind.documentary, .concert, .standup, .animation, .show] {
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
    XCTAssertEqual(MediaItem.mock(id: 1, type: "concert").presentation.kind, .concert)
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

// MARK: - Related shelves

final class RelatedShelfPolicyTests: XCTestCase {

  private func profile(type: String = "movie", genres: [(Int, String)] = []) -> MediaPresentationProfile {
    MediaPresentationProfile(
      type: type,
      genres: genres.map { TypeClass(id: $0.0, title: $0.1, shortTitle: nil) }
    )
  }

  /// A singer's filmography is not what someone watching a concert wants next, so the
  /// query is every performer, narrowed to concerts.
  func testConcertAsksEveryPerformerForConcerts() {
    let policy = profile(type: "concert").castShelf
    XCTAssertTrue(policy.usesEveryName)
    XCTAssertEqual(policy.onlyType, .concert)
    XCTAssertTrue(policy.preferredTypes.isEmpty)
  }

  /// A comic's films and series are the interesting answer — preferred, not filtered:
  /// nothing is hidden, it is only ordered.
  func testStandupAsksEveryoneAndPrefersFilmsAndSeries() {
    let policy = profile(type: "movie", genres: [(101, "Стендап")]).castShelf
    XCTAssertTrue(policy.usesEveryName)
    XCTAssertNil(policy.onlyType)
    XCTAssertEqual(policy.preferredTypes, [.movie, .serial])
  }

  /// ORing a film's fifteen credited names asks for half the catalogue.
  func testFilmAsksAboutItsLeadOnly() {
    XCTAssertFalse(profile(type: "movie").castShelf.usesEveryName)
    XCTAssertFalse(profile(type: "tvshow").castShelf.usesEveryName)
  }

  func testStageKindsGetARoleWordedCastHeader() {
    XCTAssertEqual(profile(type: "concert").castShelfTitleKey(count: 1), "MediaItem_MoreFromArtist")
    XCTAssertEqual(profile(type: "concert").castShelfTitleKey(count: 2), "MediaItem_MoreFromArtists")
    let standup = profile(type: "movie", genres: [(101, "Стендап")])
    XCTAssertEqual(standup.castShelfTitleKey(count: 1), "MediaItem_MoreFromComedian")
    XCTAssertEqual(standup.castShelfTitleKey(count: 4), "MediaItem_MoreFromComedians")
    // Everywhere else the shelf names the actor instead of the role.
    XCTAssertNil(profile(type: "movie").castShelfTitleKey(count: 1))
  }

  /// A stand-up set is filed under Comedy *and* 101; 101 is the one worth asking for.
  func testSignatureGenreOutranksTheFirstOne() {
    XCTAssertEqual(profile(type: "movie", genres: [(101, "Стендап")]).signatureGenreIDs, [101])
    XCTAssertEqual(profile(type: "movie", genres: [(23, "Мультфильм")]).signatureGenreIDs, [23])
    XCTAssertTrue(profile(type: "movie").signatureGenreIDs.isEmpty)
  }
}

// MARK: - Preferred types ordering

final class PreferredTypesTests: XCTestCase {

  private func item(_ id: Int, _ type: String) throws -> MediaItem {
    let json: [String: Any] = [
      "id": id, "type": type, "title": "T", "year": 2020,
      "duration": ["average": 0, "total": 0],
      "posters": ["small": "", "medium": "", "big": "", "wide": ""]
    ]
    return try JSONDecoder().decode(MediaItem.self,
                                    from: JSONSerialization.data(withJSONObject: json))
  }

  /// An ordering, not a filter: the concerts stay, they just stop leading.
  func testPreferredTypesFloatUpAndNothingIsDropped() throws {
    let items = [try item(1, "concert"), try item(2, "movie"),
                 try item(3, "concert"), try item(4, "serial")]
    let ordered = items.preferringTypes([.movie, .serial])
    XCTAssertEqual(ordered.map(\.id), [2, 4, 1, 3])
  }

  func testNoPreferenceKeepsTheAnswerAsItCame() throws {
    let items = [try item(1, "concert"), try item(2, "movie")]
    XCTAssertEqual(items.preferringTypes([]).map(\.id), [1, 2])
  }

  /// kino.pub answers `"3d"`; `MediaType.threeD` is `"3D"`.
  func testTypeMatchIsCaseInsensitive() throws {
    let items = [try item(1, "movie"), try item(2, "3d")]
    XCTAssertEqual(items.preferringTypes([.threeD]).map(\.id), [2, 1])
  }
}
