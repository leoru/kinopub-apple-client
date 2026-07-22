//
//  BookmarkOrderTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class BookmarkOrderTests: XCTestCase {

  private func folder(_ id: Int, title: String, created: Int, updated: Int) -> Bookmark {
    Bookmark(id: id, title: title, views: 0, count: "1", created: created, updated: updated)
  }

  /// The real shape this was built from: "Gosha" was created most recently but nothing
  /// has been added to it since, while older folders gained items today.
  func testFolderAddedToMostRecentlyComesFirst() {
    let gosha = folder(1, title: "Gosha", created: 1_772_387_577, updated: 1_772_387_577)
    let maybe = folder(2, title: "maybe", created: 1_768_565_667, updated: 1_784_715_017)
    let lusya = folder(3, title: "lusya", created: 1_768_161_190, updated: 1_784_715_014)

    let ordered = [gosha, maybe, lusya].recentlyUpdatedFirst().map(\.title)

    XCTAssertEqual(ordered, ["maybe", "lusya", "Gosha"])
  }

  func testCreationDateBreaksTiesWhenNothingWasAdded() {
    let older = folder(1, title: "older", created: 100, updated: 500)
    let newer = folder(2, title: "newer", created: 200, updated: 500)

    XCTAssertEqual([older, newer].recentlyUpdatedFirst().map(\.title), ["newer", "older"])
  }

  func testOrderIsStableForIdenticalDates() {
    let first = folder(1, title: "first", created: 100, updated: 500)
    let second = folder(2, title: "second", created: 100, updated: 500)

    XCTAssertEqual([first, second].recentlyUpdatedFirst().map(\.id), [2, 1])
    XCTAssertEqual([second, first].recentlyUpdatedFirst().map(\.id), [2, 1])
  }
}
