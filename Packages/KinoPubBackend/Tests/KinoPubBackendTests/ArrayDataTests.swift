import XCTest
@testable import KinoPubBackend

final class ArrayDataTests: XCTestCase {

  func testDecodesItemsKey() throws {
    let json = Data(#"{"items":[{"id":1,"title":"хочу","views":0,"count":"0","created":1,"updated":1}]}"#.utf8)
    let decoded = try JSONDecoder().decode(ArrayData<Bookmark>.self, from: json)
    XCTAssertEqual(decoded.items.count, 1)
    XCTAssertEqual(decoded.items.first?.id, 1)
  }

  /// Live `GET /v1/bookmarks/get-item-folders` uses `folders`, not `items`.
  func testDecodesFoldersKey() throws {
    let json = Data(#"{"status":200,"folders":[{"id":1301686,"title":"хочу посмотреть","views":139,"count":"525","created":1656378309,"updated":1784715002}]}"#.utf8)
    let decoded = try JSONDecoder().decode(ArrayData<Bookmark>.self, from: json)
    XCTAssertEqual(decoded.items.count, 1)
    XCTAssertEqual(decoded.items.first?.id, 1301686)
  }

  func testEmptyFoldersIsValid() throws {
    let json = Data(#"{"status":200,"folders":[]}"#.utf8)
    let decoded = try JSONDecoder().decode(ArrayData<Bookmark>.self, from: json)
    XCTAssertTrue(decoded.items.isEmpty)
  }
}
