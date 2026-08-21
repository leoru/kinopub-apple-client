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

  /// Anime and cartoons are drawn the same way, so they share a `kind` — but only one of
  /// them is normally watched in the original with subtitles, so `isAnime` is separate.
  func testAnimeIsTheOnlyAnimationThatIsAnime() {
    XCTAssertTrue(profile(type: "serial", genres: [(2, "Аниме")]).isAnime)
    XCTAssertTrue(profile(type: "serial", genres: [(2, "Anime")]).isAnime)
    XCTAssertFalse(profile(type: "movie", genres: [(23, "Мультфильм")]).isAnime)
    XCTAssertFalse(profile(type: "serial", genres: [(23, "Мультсериал")]).isAnime)
    XCTAssertFalse(profile(type: "movie", genres: [(1, "Комедия")]).isAnime)
  }

  func testAnimeStillPresentsAsAnimation() {
    XCTAssertEqual(profile(type: "serial", genres: [(2, "Аниме")]).kind, .animation)
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

// MARK: - Related shelves

final class RelatedShelfPolicyTests: XCTestCase {

  private func profile(type: String = "movie", genres: [(Int, String)] = []) -> MediaPresentationProfile {
    MediaPresentationProfile(
      type: type,
      genres: genres.map { TypeClass(id: $0.0, title: $0.1, shortTitle: nil) }
    )
  }

  private func standup() -> MediaPresentationProfile {
    profile(type: "movie", genres: [(1, "Комедия"), (101, "Стендап")])
  }

  private func anime() -> MediaPresentationProfile {
    profile(type: "serial", genres: [(2, "Аниме")])
  }

  // MARK: Who the cast shelf asks for

  /// A singer's filmography is not what someone watching a concert wants next, so the
  /// two people on stage are asked for their concerts.
  func testConcertAsksItsPerformersForConcerts() {
    let policy = profile(type: "concert").castShelf
    XCTAssertEqual(policy.nameLimit, 2)
    XCTAssertEqual(policy.onlyType, .concert)
    XCTAssertTrue(policy.preferredTypes.isEmpty)
  }

  /// A comic's films and series are the interesting answer — preferred, not filtered:
  /// nothing is hidden, it is only ordered.
  func testStandupAsksItsParticipantsAndPrefersFilmsAndSeries() {
    let policy = standup().castShelf
    XCTAssertEqual(policy.nameLimit, 2)
    XCTAssertNil(policy.onlyType)
    XCTAssertEqual(policy.preferredTypes, [.movie, .serial])
  }

  /// Two names is a shelf; a film credits fifteen, and each name is its own request.
  func testNoKindAsksAboutMoreThanTwoNames() {
    for kind in MediaPresentationKind.allCases {
      let limit = MediaPresentationProfile(kind: kind).castShelf.nameLimit
      XCTAssertLessThanOrEqual(limit, 2, "\(kind)")
    }
    XCTAssertEqual(profile(type: "movie").castShelf.nameLimit, 1)
    XCTAssertEqual(profile(type: "tvshow").castShelf.nameLimit, 1)
  }

  /// kino.pub's `cast` on anything drawn is the voice actors: a name the viewer never
  /// heard, over a face that was never on screen.
  func testAnimationGetsNoCastShelfAtAll() {
    XCTAssertFalse(anime().showsCastShelf)
    XCTAssertEqual(anime().castShelf.nameLimit, 0)
    XCTAssertFalse(profile(type: "movie", genres: [(23, "Мультфильм")]).showsCastShelf)
    for kind in [MediaPresentationKind.fiction, .documentary, .concert, .standup, .show] {
      XCTAssertTrue(MediaPresentationProfile(kind: kind).showsCastShelf, "\(kind)")
    }
  }

  func testStageKindsGetARoleWordedCastHeader() {
    XCTAssertEqual(profile(type: "concert").castShelfTitleKey(count: 1), "MediaItem_MoreFromArtist")
    XCTAssertEqual(profile(type: "concert").castShelfTitleKey(count: 2), "MediaItem_MoreFromArtists")
    XCTAssertEqual(standup().castShelfTitleKey(count: 1), "MediaItem_MoreFromComedian")
    XCTAssertEqual(standup().castShelfTitleKey(count: 2), "MediaItem_MoreFromComedians")
    // Everywhere else the shelf names the actor instead of the role.
    XCTAssertNil(profile(type: "movie").castShelfTitleKey(count: 1))
  }

  // MARK: The genre floor

  /// A film asks for one genre — "more comedy" under a comedy is a truism, and its
  /// other shelves carry the page. Everything else is described by the combination.
  func testOnlyFilmsAskForASingleGenre() {
    XCTAssertFalse(profile(type: "movie").genreShelfUsesEveryGenre)
    XCTAssertFalse(profile(type: "3d").genreShelfUsesEveryGenre)
    for type in ["tvshow", "concert", "documovie", "docuserial"] {
      XCTAssertTrue(profile(type: type).genreShelfUsesEveryGenre, type)
    }
    XCTAssertTrue(anime().genreShelfUsesEveryGenre)
    XCTAssertTrue(standup().genreShelfUsesEveryGenre)
  }

  /// A stand-up set is filed under Comedy *and* 101; 101 is the one worth asking for.
  func testSignatureGenreOutranksTheFirstOne() {
    XCTAssertEqual(standup().signatureGenreIDs, [101])
    XCTAssertEqual(anime().signatureGenreIDs, [23])
    XCTAssertTrue(profile(type: "movie").signatureGenreIDs.isEmpty)
  }
}

// MARK: - One request per credited name

final class CreditQueryTests: XCTestCase {

  /// 🔴 The API matches `director` against the credits as written: a comma-joined pair
  /// matches nothing. Each name is its own request.
  func testEachNameBecomesItsOwnPerson() {
    let people = MediaPerson.each(of: ["Фил Лорд", "Кристофер Миллер"],
                                  role: .director, limit: 2)
    XCTAssertEqual(people.map(\.name), ["Фил Лорд", "Кристофер Миллер"])
    XCTAssertTrue(people.allSatisfy { !$0.name.contains(",") })
  }

  func testLimitCapsHowManyRequestsAShelfCosts() {
    let cast = ["A", "B", "C", "D", "E"]
    XCTAssertEqual(MediaPerson.each(of: cast, role: .actor, limit: 1).count, 1)
    XCTAssertEqual(MediaPerson.each(of: cast, role: .actor, limit: 2).count, 2)
    XCTAssertTrue(MediaPerson.each(of: cast, role: .actor, limit: 0).isEmpty)
  }

  func testBlankNamesNeverBecomeAQuery() {
    XCTAssertTrue(MediaPerson.each(of: ["", "   "], role: .director, limit: 2).isEmpty)
    XCTAssertEqual(MediaPerson.each(of: ["", " Джеймс Ганн "], role: .director, limit: 2)
      .map(\.name), ["Джеймс Ганн"])
  }
}

// MARK: - Query parameters

final class ShelfQueryParameterTests: XCTestCase {

  private func params(_ filter: LibraryFilter) -> [String: String] {
    (ItemsRequest(filter: filter, page: nil).parameters as? [String: String]) ?? [:]
  }

  /// Commas *are* OR on `genre` — this is the one parameter where several values in one
  /// request is the point.
  func testSeveralGenresGoAsOneCommaSeparatedValue() {
    XCTAssertEqual(params(LibraryFilter(genreIDs: [5, 23, 101]))["genre"], "5,23,101")
  }

  func testSingleGenreStillWorksAndGenreIDsWins() {
    XCTAssertEqual(params(LibraryFilter(genreID: 7))["genre"], "7")
    XCTAssertEqual(params(LibraryFilter(genreID: 7, genreIDs: [1, 2]))["genre"], "1,2")
  }

  /// A credit query carries exactly one name — never a joined list.
  func testCreditQueryCarriesOneName() {
    let filter = LibraryFilter(person: MediaPerson(name: "Фил Лорд", role: .director))
    XCTAssertEqual(params(filter)["director"], "Фил Лорд")
    XCTAssertNil(params(filter)["cast"])
  }

  /// The genre floor asks for what is new, not for the all-time top of a genre.
  func testGenreFloorSortIsFreshness() {
    XCTAssertEqual(MediaSortOrder.recentlyAdded.apiValue, "-created")
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
