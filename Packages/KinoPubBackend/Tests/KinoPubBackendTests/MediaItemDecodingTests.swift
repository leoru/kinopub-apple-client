import XCTest
@testable import KinoPubBackend

final class MediaItemDecodingTests: XCTestCase {

  /// Actor credit lists have returned `updated_at: null` (and occasionally other
  /// soft ints). That must not blank the whole page.
  func testNullSoftFieldsStillDecode() throws {
    let json = """
    {
      "id": 1,
      "type": "movie",
      "subtype": "",
      "title": "Test / Test",
      "year": null,
      "cast": "Someone",
      "director": "Someone",
      "genres": [],
      "countries": [],
      "voice": null,
      "duration": {"average": 100, "total": 100},
      "langs": null,
      "quality": null,
      "plot": "",
      "imdb": null,
      "imdb_rating": null,
      "imdb_votes": null,
      "kinopoisk": null,
      "kinopoisk_rating": null,
      "kinopoisk_votes": null,
      "rating": null,
      "rating_votes": null,
      "rating_percentage": null,
      "views": null,
      "comments": null,
      "posters": {"small": "", "medium": "", "big": "", "wide": ""},
      "trailer": null,
      "finished": false,
      "advert": false,
      "poor_quality": false,
      "created_at": null,
      "updated_at": null,
      "subscribed": false,
      "in_watchlist": false
    }
    """.data(using: .utf8)!

    let item = try JSONDecoder().decode(MediaItem.self, from: json)
    XCTAssertEqual(item.id, 1)
    XCTAssertEqual(item.year, 0)
    XCTAssertEqual(item.createdAt, 0)
    XCTAssertEqual(item.updatedAt, 0)
    XCTAssertEqual(item.langs, 0)
    XCTAssertEqual(item.quality, 0)
    XCTAssertEqual(item.rating, 0)
    XCTAssertEqual(item.ratingVotes, 0)
    XCTAssertEqual(item.ratingPercentage, 0)
    XCTAssertEqual(item.views, 0)
    XCTAssertEqual(item.comments, 0)
    XCTAssertTrue(item.uploadedSameDayAsUpdated)
  }
}
