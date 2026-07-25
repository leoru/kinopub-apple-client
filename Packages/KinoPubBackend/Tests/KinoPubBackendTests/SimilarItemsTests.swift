import XCTest
@testable import KinoPubBackend

final class SimilarItemsTests: XCTestCase {

  private func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: name,
                                              withExtension: "json",
                                              subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
  }

  /// Live payload from `GET /v1/items/similar?id=100` — proves the envelope and
  /// list-shaped `MediaItem` decode the way the detail page expects.
  func testDecodesRealSimilarEnvelope() throws {
    let decoded = try JSONDecoder().decode(ArrayData<MediaItem>.self,
                                           from: try fixture("similar_100"))
    XCTAssertEqual(decoded.items.count, 10)
    XCTAssertFalse(decoded.items[0].title.isEmpty)
    XCTAssertGreaterThan(decoded.items[0].id, 0)
  }

  /// Mortal Kombat 2 (`123391`) — API answers 200 with an empty list, so the
  /// section correctly stays hidden rather than decoding as a failure.
  func testEmptySimilarIsValid() throws {
    let decoded = try JSONDecoder().decode(ArrayData<MediaItem>.self,
                                           from: try fixture("similar_123391"))
    XCTAssertTrue(decoded.items.isEmpty)
  }
}
