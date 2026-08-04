//
//  CatalogLoadMoreTests.swift
//

import XCTest
@testable import KinoPubBackend

final class CatalogLoadMoreTests: XCTestCase {

  func testThresholdIsLastItemById() {
    let items = (1...500).map { MediaItem.mock(id: $0) }

    XCTAssertFalse(CatalogLoadMore.isThresholdItem(items[0], in: items))
    XCTAssertFalse(CatalogLoadMore.isThresholdItem(items[249], in: items))
    XCTAssertTrue(CatalogLoadMore.isThresholdItem(items[499], in: items))
    XCTAssertFalse(CatalogLoadMore.isThresholdItem(MediaItem.mock(id: 999), in: items))
  }

  func testThresholdIDMatchesLastCard() {
    XCTAssertTrue(CatalogLoadMore.isThresholdID(42, lastID: 42))
    XCTAssertFalse(CatalogLoadMore.isThresholdID(1, lastID: 42))
    XCTAssertFalse(CatalogLoadMore.isThresholdID(1, lastID: nil))
  }

  func testThresholdIsFalseForEmptyList() {
    XCTAssertFalse(CatalogLoadMore.isThresholdItem(MediaItem.mock(id: 1), in: []))
  }

  /// Simulates a LazyVGrid scroll pass: every card's `.onAppear` asks whether it
  /// is the load-more threshold. Must stay O(n) overall (one id check each), not
  /// O(n²) deep `MediaItem` equality via `firstIndex(of:)`.
  func testScrollPassOverLargeListStaysCheap() {
    let items = (1...500).map { MediaItem.mock(id: $0) }
    let lastID = items.last!.id

    var triggerCount = 0
    measure {
      triggerCount = 0
      for item in items {
        if CatalogLoadMore.isThresholdItem(item, in: items) {
          triggerCount += 1
        }
      }
    }

    XCTAssertEqual(triggerCount, 1)
    XCTAssertEqual(items.last?.id, lastID)
  }
}
