//
//  BookmarkItemsRequestTests.swift
//

import XCTest
@testable import KinoPubBackend

final class BookmarkItemsRequestTests: XCTestCase {

  func testPageParameterIsSentWhenProvided() {
    let request = BookmarkItemsRequest(id: "42", page: 3)
    XCTAssertEqual(request.path, "/v1/bookmarks/42")
    XCTAssertEqual(request.parameters?["page"] as? String, "3")
  }

  func testOmitsPageWhenNil() {
    let request = BookmarkItemsRequest(id: "7")
    XCTAssertNil(request.parameters)
  }

  func testDecodesItemsWithOptionalPagination() throws {
    let json = Data("""
    {
      "status": 200,
      "items": [{
        "id": 1,
        "type": "movie",
        "subtype": "",
        "title": "A",
        "year": 2020,
        "cast": "",
        "director": "",
        "genres": [],
        "countries": [],
        "voice": null,
        "duration": {"average": 100, "total": 100},
        "langs": 0,
        "quality": 0,
        "plot": "",
        "imdb": null,
        "imdb_rating": null,
        "imdb_votes": null,
        "kinopoisk": null,
        "kinopoisk_rating": null,
        "kinopoisk_votes": null,
        "rating": 0,
        "rating_votes": 0,
        "rating_percentage": 0,
        "views": 0,
        "comments": 0,
        "posters": {"small": "", "medium": "", "big": ""},
        "trailer": null,
        "finished": false,
        "advert": false,
        "poor_quality": false,
        "created_at": 0,
        "updated_at": 0,
        "subscribed": false,
        "in_watchlist": false
      }],
      "pagination": {"total": 4, "current": 1, "perpage": 20}
    }
    """.utf8)
    let decoded = try JSONDecoder().decode(BookmarkFolderItemsData.self, from: json)
    XCTAssertEqual(decoded.items.count, 1)
    XCTAssertEqual(decoded.pagination?.total, 4)
    XCTAssertEqual(decoded.pagination?.current, 1)
  }

  func testDecodesItemsWithoutPagination() throws {
    let json = Data("""
    {
      "status": 200,
      "items": [{
        "id": 2,
        "type": "movie",
        "subtype": "",
        "title": "B",
        "year": 2020,
        "cast": "",
        "director": "",
        "genres": [],
        "countries": [],
        "voice": null,
        "duration": {"average": 100, "total": 100},
        "langs": 0,
        "quality": 0,
        "plot": "",
        "imdb": null,
        "imdb_rating": null,
        "imdb_votes": null,
        "kinopoisk": null,
        "kinopoisk_rating": null,
        "kinopoisk_votes": null,
        "rating": 0,
        "rating_votes": 0,
        "rating_percentage": 0,
        "views": 0,
        "comments": 0,
        "posters": {"small": "", "medium": "", "big": ""},
        "trailer": null,
        "finished": false,
        "advert": false,
        "poor_quality": false,
        "created_at": 0,
        "updated_at": 0,
        "subscribed": false,
        "in_watchlist": false
      }]
    }
    """.utf8)
    let decoded = try JSONDecoder().decode(BookmarkFolderItemsData.self, from: json)
    XCTAssertEqual(decoded.items.count, 1)
    XCTAssertNil(decoded.pagination)
  }
}
