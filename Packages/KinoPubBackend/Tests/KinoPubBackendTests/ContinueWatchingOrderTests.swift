//
//  ContinueWatchingOrderTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class ContinueWatchingOrderTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_000_000_000)

  private func item(_ id: Int) -> WatchingItem {
    WatchingItem(id: id,
                 type: "serial",
                 title: "Item \(id)",
                 posters: Posters(small: "", medium: "", big: "", wide: nil))
  }

  private func daysAgo(_ days: Double) -> Date {
    now.addingTimeInterval(-days * 24 * 60 * 60)
  }

  private func order(_ items: [WatchingItem],
                     watchlist: Set<Int> = [],
                     lastSeen: [Int: Date] = [:]) -> [Int] {
    ContinueWatchingOrder.ordered(items: items,
                                  watchlistIDs: watchlist,
                                  lastSeen: lastSeen,
                                  now: now).map(\.id)
  }

  func testRecentNonWatchlistComesBeforeWatchlist() {
    let result = order([item(1), item(2)],
                       watchlist: [1],
                       lastSeen: [1: daysAgo(1), 2: daysAgo(2)])

    XCTAssertEqual(result, [2, 1], "an aside watched 2 days ago should outrank the watchlist")
  }

  func testWatchlistComesBeforeEverythingElse() {
    let result = order([item(1), item(2)],
                       watchlist: [2],
                       lastSeen: [1: daysAgo(30), 2: daysAgo(60)])

    XCTAssertEqual(result, [2, 1])
  }

  func testFullThreeBucketOrdering() {
    // 1: stale aside · 2: watchlist · 3: recent aside
    let result = order([item(1), item(2), item(3)],
                       watchlist: [2],
                       lastSeen: [1: daysAgo(20), 2: daysAgo(20), 3: daysAgo(3)])

    XCTAssertEqual(result, [3, 2, 1])
  }

  func testAsideOlderThanAWeekDropsToTheLastBucket() {
    let result = order([item(1), item(2)],
                       watchlist: [2],
                       lastSeen: [1: daysAgo(8), 2: daysAgo(100)])

    XCTAssertEqual(result, [2, 1], "8 days is outside the window, so it loses to the watchlist")
  }

  func testSevenDaysExactlyStillCountsAsRecent() {
    let result = order([item(1), item(2)],
                       watchlist: [2],
                       lastSeen: [1: daysAgo(7), 2: daysAgo(1)])

    XCTAssertEqual(result, [1, 2])
  }

  func testWithinABucketNewestFirst() {
    let result = order([item(1), item(2), item(3)],
                       watchlist: [1, 2, 3],
                       lastSeen: [1: daysAgo(10), 2: daysAgo(2), 3: daysAgo(5)])

    XCTAssertEqual(result, [2, 3, 1])
  }

  func testItemsWithoutHistorySinkWithinTheirBucket() {
    let result = order([item(1), item(2)],
                       watchlist: [1, 2],
                       lastSeen: [2: daysAgo(40)])

    XCTAssertEqual(result, [2, 1])
  }

  func testUnknownHistoryKeepsAPIOrderAsTiebreak() {
    XCTAssertEqual(order([item(3), item(1), item(2)], watchlist: [1, 2, 3]), [3, 1, 2])
  }

  func testEmptyInputProducesEmptyOutput() {
    XCTAssertEqual(order([]), [])
  }

  // MARK: - History collapsing

  func testLastSeenKeepsTheNewestEpisodePerTitle() {
    let history = [
      HistoryEntry(item: .init(id: 7), lastSeen: 100),
      HistoryEntry(item: .init(id: 7), lastSeen: 300),
      HistoryEntry(item: .init(id: 7), lastSeen: 200),
      HistoryEntry(item: .init(id: 9), lastSeen: 50)
    ]

    let collapsed = ContinueWatchingOrder.lastSeenByItemID(history)

    XCTAssertEqual(collapsed[7], Date(timeIntervalSince1970: 300))
    XCTAssertEqual(collapsed[9], Date(timeIntervalSince1970: 50))
  }

  func testLastSeenIgnoresMissingAndZeroTimestamps() {
    let history = [
      HistoryEntry(item: .init(id: 1), lastSeen: nil),
      HistoryEntry(item: .init(id: 2), lastSeen: 0)
    ]

    XCTAssertTrue(ContinueWatchingOrder.lastSeenByItemID(history).isEmpty)
  }
}
