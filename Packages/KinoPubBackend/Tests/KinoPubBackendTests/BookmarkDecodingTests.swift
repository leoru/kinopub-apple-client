//
//  BookmarkDecodingTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class BookmarkDecodingTests: XCTestCase {

  private func decode(_ json: String) throws -> Bookmark {
    try JSONDecoder().decode(Bookmark.self, from: Data(json.utf8))
  }

  func testCountArrivingAsAStringIsKept() throws {
    let folder = try decode(#"{"id":1,"title":"maybe","views":1,"count":"43","created":1,"updated":2}"#)

    XCTAssertEqual(folder.count, "43")
  }

  func testNumericCountBecomesAString() throws {
    let folder = try decode(#"{"id":1,"title":"maybe","views":1,"count":43,"created":1,"updated":2}"#)

    XCTAssertEqual(folder.count, "43")
  }

  /// `/v1/bookmarks/get-item-folders` returns folders with no `count` key at all. This
  /// used to throw, which failed the whole response and left the item page unable to say
  /// which folders it belonged to.
  func testFolderWithNoCountStillDecodes() throws {
    let folder = try decode(#"""
      {"id":1301686,"user_id":5916,"title":"хочу посмотреть","created_at":1656378309,
       "updated_at":1785141530,"views":140,"created":1656378309,"updated":1785141530}
      """#)

    XCTAssertEqual(folder.id, 1_301_686)
    XCTAssertEqual(folder.title, "хочу посмотреть")
    XCTAssertEqual(folder.count, "")
  }

  func testFolderListResponseDecodesWithoutCounts() throws {
    let json = #"""
      {"status":200,"folders":[
        {"id":1301686,"user_id":5916,"title":"хочу посмотреть","views":140,
         "created":1656378309,"updated":1785141530}
      ]}
      """#
    let response = try JSONDecoder().decode(ArrayData<Bookmark>.self, from: Data(json.utf8))

    XCTAssertEqual(response.items.map(\.title), ["хочу посмотреть"])
  }
}
