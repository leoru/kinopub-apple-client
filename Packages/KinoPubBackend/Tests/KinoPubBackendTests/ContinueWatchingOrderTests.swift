//
//  ContinueWatchingOrderTests.swift
//

import XCTest
@testable import KinoPubBackend

final class ContinueWatchingOrderTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_000_000_000)

  private func item(_ id: Int, new: Int? = nil) -> WatchingItem {
    WatchingItem(id: id,
                 type: "serial",
                 title: "Item \(id)",
                 posters: Posters(small: "", medium: "", big: "", wide: nil),
                 total: 10,
                 watched: 5,
                 new: new)
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

  func testRecentlyStartedBeatsWatchlistWithNewEpisodes() {
    let result = order([item(1, new: 3), item(2)],
                       watchlist: [1],
                       lastSeen: [2: daysAgo(1)])

    XCTAssertEqual(result, [2, 1], "a title started yesterday outranks a watchlist drop")
  }

  func testRecentlyReleasedBeatsPlainWatchlist() {
    let result = order([item(1), item(2, new: 4)],
                       watchlist: [1, 2],
                       lastSeen: [:])

    XCTAssertEqual(result, [2, 1])
  }

  func testWatchlistBeatsOtherUnfinished() {
    let result = order([item(1), item(2)],
                       watchlist: [2],
                       lastSeen: [1: daysAgo(30), 2: daysAgo(60)])

    XCTAssertEqual(result, [2, 1])
  }

  func testFullFourBucketOrdering() {
    // 1: rest · 2: watchlist · 3: recently released · 4: recently started
    let result = order([item(1), item(2), item(3, new: 2), item(4)],
                       watchlist: [2, 3],
                       lastSeen: [1: daysAgo(20), 2: daysAgo(20), 4: daysAgo(2)])

    XCTAssertEqual(result, [4, 3, 2, 1])
  }

  func testAsideOlderThanAWeekIsNotRecentlyStarted() {
    let result = order([item(1), item(2, new: 1)],
                       watchlist: [2],
                       lastSeen: [1: daysAgo(8)])

    XCTAssertEqual(result, [2, 1], "8 days is outside the window")
  }

  func testSevenDaysExactlyStillCountsAsRecentlyStarted() {
    let result = order([item(1), item(2, new: 1)],
                       watchlist: [2],
                       lastSeen: [1: daysAgo(7)])

    XCTAssertEqual(result, [1, 2])
  }

  func testRecentlyStartedWatchlistItemStaysInStartedBucket() {
    let result = order([item(1, new: 5), item(2)],
                       watchlist: [1],
                       lastSeen: [1: daysAgo(1), 2: daysAgo(2)])

    XCTAssertEqual(result, [1, 2], "recent play wins over the new-episode badge")
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

  // MARK: - Pool merge

  func testMergePoolUnionsWatchlistWithoutLosingOrder() {
    let movies = [item(10)]
    let serials = [item(1), item(2)]
    let watchlist = [item(2, new: 3), item(9, new: 1)]

    let merged = ContinueWatchingOrder.mergePool(movies: movies, serials: serials, watchlist: watchlist)

    XCTAssertEqual(merged.map(\.id), [1, 2, 10, 9])
    XCTAssertEqual(merged.first { $0.id == 2 }?.new, 3, "watchlist copy keeps the +N badge")
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

  // MARK: - Backlog tiebreak

  /// The watching endpoints carry no timestamps, so two subscribed shows with new
  /// episodes and nothing in the fetched history page tie on bucket *and* date. The
  /// tie used to go to the server's list order, which put a cartoon abandoned years ago
  /// above a show with one episode waiting.
  func testUndatedTitlesInOneBucketSortByFewestUnwatchedEpisodes() {
    let abandoned = WatchingItem.mock(id: 1, title: "Abandoned", new: 171)
    let followed = WatchingItem.mock(id: 2, title: "Followed", new: 1)

    let ordered = ContinueWatchingOrder.ordered(items: [abandoned, followed],
                                                watchlistIDs: [1, 2],
                                                lastSeen: [:])

    XCTAssertEqual(ordered.map(\.id), [2, 1])
  }

  /// A real play still wins: the backlog only decides ties.
  func testADateStillBeatsASmallerBacklog() {
    let now = Date()
    let abandoned = WatchingItem.mock(id: 1, title: "Abandoned", new: 171)
    let followed = WatchingItem.mock(id: 2, title: "Followed", new: 1)

    let ordered = ContinueWatchingOrder.ordered(items: [followed, abandoned],
                                                watchlistIDs: [1, 2],
                                                lastSeen: [1: now.addingTimeInterval(-60)],
                                                now: now)

    XCTAssertEqual(ordered.map(\.id), [1, 2], "played an hour ago outranks a short backlog")
  }

  /// Films have no counters. Zero is the right reading — one press from finished.
  func testAFilmOutranksASerialWithEpisodesToGo() {
    let film = WatchingItem(id: 1,
                            type: "movie",
                            subtype: "",
                            title: "Film",
                            posters: Posters(small: "", medium: "", big: "", wide: nil),
                            total: nil,
                            watched: nil,
                            new: nil)
    let serial = WatchingItem.mock(id: 2, title: "Serial", new: 8)

    let ordered = ContinueWatchingOrder.ordered(items: [serial, film],
                                                watchlistIDs: [],
                                                lastSeen: [:])

    XCTAssertEqual(ordered.map(\.id), [1, 2])
  }
}
