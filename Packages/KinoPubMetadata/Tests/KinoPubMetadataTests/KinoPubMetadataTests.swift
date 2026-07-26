import XCTest
@testable import KinoPubMetadata

final class TMDBIDFormatterTests: XCTestCase {
  func testPadsToSevenDigits() {
    XCTAssertEqual(TMDBIDFormatter.imdbString(from: 42), "tt0000042")
    XCTAssertEqual(TMDBIDFormatter.imdbString(from: 903_747), "tt0903747")
  }

  func testLongIdsUnpadded() {
    XCTAssertEqual(TMDBIDFormatter.imdbString(from: 12_345_678), "tt12345678")
  }
}

final class TMDBDTODecodingTests: XCTestCase {
  private let client = MetadataHTTPClient()

  func testFindMovie() throws {
    let data = try fixture("find_movie")
    let response = try client.decode(TMDBFindResponse.self, from: data)
    let match = response.match(preferSeries: false)
    XCTAssertEqual(match?.id, 550)
    XCTAssertEqual(match?.type, .movie)
  }

  func testFindTV() throws {
    let data = try fixture("find_tv")
    let response = try client.decode(TMDBFindResponse.self, from: data)
    let match = response.match(preferSeries: true)
    XCTAssertEqual(match?.id, 1399)
    XCTAssertEqual(match?.type, .tv)
  }

  func testMovieDetailsCastAndLogoPreference() throws {
    let data = try fixture("movie_details")
    let details = try client.decode(TMDBTitleDetails.self, from: data)
    XCTAssertEqual(details.credits?.cast?.count, 2)
    XCTAssertEqual(details.credits?.cast?.first?.character, "The Narrator")
    // ru preferred over higher-voted en/null
    XCTAssertEqual(details.images?.bestLogoPath(preferring: ["ru", "en", nil]), "/ruLogo.png")
    XCTAssertEqual(details.images?.bestLogoPath(preferring: ["en", nil]), "/enLogo.png")
  }

  func testTVAggregateCreditsAndAgeRating() throws {
    let data = try fixture("tv_details")
    let details = try client.decode(TMDBTitleDetails.self, from: data)
    let cast = details.aggregateCredits?.cast?.first
    XCTAssertEqual(cast?.name, "Peter Dinklage")
    XCTAssertEqual(cast?.primaryCharacter, "Tyrion Lannister")
    XCTAssertEqual(details.lastEpisodeToAir?.episodeNumber, 6)
  }

  func testSeasonScheduleAndUpcoming() throws {
    let data = try fixture("season_1")
    let season = try client.decode(TMDBSeasonDetails.self, from: data)
    XCTAssertEqual(season.episodes?.count, 3)
    let future = season.episodes?.last
    let air = TMDBSource.parseDate(future?.airDate)
    XCTAssertNotNil(air)
    let schedule = EpisodeSchedule(
      episodeNumber: future!.episodeNumber!,
      seasonNumber: 1,
      airDate: air
    )
    XCTAssertTrue(schedule.isUpcoming)
  }

  private func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
      ?? Bundle.module.url(forResource: name, withExtension: "json")
    )
    return try Data(contentsOf: url)
  }
}

final class TitleMetadataMergeTests: XCTestCase {
  func testEnrichFillsPhotoAndCharacterKeepingKinoPubOrder() {
    var meta = TitleMetadata()
    meta.cast = [
      CastMember(name: "Brad Pitt", character: "Tyler Durden",
                 photo: URL(string: "https://image.tmdb.org/t/p/w185/a.jpg")),
      CastMember(name: "Edward Norton", character: "The Narrator",
                 photo: URL(string: "https://image.tmdb.org/t/p/w185/b.jpg")),
    ]
    let enriched = TitleMetadata.enrich(
      names: ["Edward Norton", "Someone Else", "Brad Pitt"],
      roleDepartment: "Acting",
      from: meta
    )
    XCTAssertEqual(enriched.map(\.name), ["Edward Norton", "Someone Else", "Brad Pitt"])
    XCTAssertEqual(enriched[0].character, "The Narrator")
    XCTAssertNotNil(enriched[0].photo)
    XCTAssertNil(enriched[1].photo)
    XCTAssertEqual(enriched[2].character, "Tyler Durden")
  }

  func testMergePrefersExistingLogo() {
    var base = TitleMetadata()
    base.artwork.titleLogo = URL(string: "https://example.com/a.png")
    var other = TitleMetadata()
    other.artwork.titleLogo = URL(string: "https://example.com/b.png")
    other.cast = [CastMember(name: "A")]
    base.merge(other)
    XCTAssertEqual(base.artwork.titleLogo?.absoluteString, "https://example.com/a.png")
    XCTAssertEqual(base.cast.count, 1)
  }
}

final class TMDBImageURLTests: XCTestCase {
  func testBuildsCDNURL() {
    let url = TMDBImageURL.url(path: "/abc.png", size: .logoW500)
    XCTAssertEqual(url?.absoluteString, "https://image.tmdb.org/t/p/w500/abc.png")
  }

  func testBuildsProxiedURL() {
    let proxy = URL(string: "https://kinopub-tmdb-proxy.example.workers.dev")!
    let url = TMDBImageURL.url(path: "/abc.png", size: .profileW185, proxyBase: proxy)
    XCTAssertEqual(
      url?.absoluteString,
      "https://kinopub-tmdb-proxy.example.workers.dev/t/p/w185/abc.png"
    )
  }

  func testNilPath() {
    XCTAssertNil(TMDBImageURL.url(path: nil, size: .profileW185))
    XCTAssertNil(TMDBImageURL.url(path: "", size: .profileW185))
  }
}
