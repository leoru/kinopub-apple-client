//
//  ContinueWatchingLocalOverlayTests.swift
//

import XCTest
@testable import KinoPubBackend

final class ContinueWatchingLocalOverlayTests: XCTestCase {

  func testInProgressLocalUpdatesProgressAndLeads() {
    let cards = [
      ContinueWatchingLocalOverlay.Card(itemID: 1, isSeries: false, season: nil, video: 1),
      ContinueWatchingLocalOverlay.Card(itemID: 2, isSeries: false, season: nil, video: 1)
    ]
    let locals = [
      local(id: 2, progress: 0.4, updatedAt: 20, isSeries: false)
    ]
    let plan = ContinueWatchingLocalOverlay.plan(cards: cards, locals: locals)

    XCTAssertEqual(plan.order, [2, 1])
    XCTAssertEqual(plan.mutations[2]?.progress, 0.4)
    XCTAssertTrue(plan.hiddenIDs.isEmpty)
    XCTAssertTrue(plan.insertIDs.isEmpty)
  }

  func testFinishedFilmIsHidden() {
    let cards = [
      ContinueWatchingLocalOverlay.Card(itemID: 10, isSeries: false, season: nil, video: 1)
    ]
    let locals = [
      local(id: 10, isFinished: true, isSeries: false, updatedAt: 5)
    ]
    let plan = ContinueWatchingLocalOverlay.plan(cards: cards, locals: locals)

    XCTAssertEqual(plan.hiddenIDs, [10])
    XCTAssertTrue(plan.order.isEmpty)
    XCTAssertNil(plan.mutations[10])
  }

  func testFinishedSeriesEpisodeAdvancesAndClearsProgress() {
    let cards = [
      ContinueWatchingLocalOverlay.Card(itemID: 7, isSeries: true, season: 1, video: 4)
    ]
    let locals = [
      local(id: 7, season: 1, episode: 4, isFinished: true, isSeries: true, updatedAt: 9)
    ]
    let plan = ContinueWatchingLocalOverlay.plan(cards: cards, locals: locals)

    XCTAssertTrue(plan.hiddenIDs.isEmpty)
    XCTAssertEqual(plan.mutations[7]?.video, 5)
    XCTAssertEqual(plan.mutations[7]?.season, 1)
    XCTAssertNil(plan.mutations[7]?.progress)
    XCTAssertEqual(plan.mutations[7]?.overlayLabel, "S1, E5")
    XCTAssertEqual(plan.order, [7])
  }

  func testLocalOnlyInsertLeadsTheRow() {
    let cards = [
      ContinueWatchingLocalOverlay.Card(itemID: 1, isSeries: false, season: nil, video: 1)
    ]
    let locals = [
      local(id: 99, progress: 0.2, updatedAt: 50, isSeries: false, canInsert: true)
    ]
    let plan = ContinueWatchingLocalOverlay.plan(cards: cards, locals: locals)

    XCTAssertEqual(plan.insertIDs, [99])
    XCTAssertEqual(plan.order, [99, 1])
    XCTAssertEqual(plan.mutations[99]?.progress, 0.2)
  }

  func testFinishedSeriesNotInTheRowIsNotInserted() {
    let plan = ContinueWatchingLocalOverlay.plan(
      cards: [],
      locals: [local(id: 7, season: 1, episode: 10, isFinished: true, isSeries: true, updatedAt: 9, canInsert: true)]
    )
    XCTAssertTrue(plan.insertIDs.isEmpty)
    XCTAssertTrue(plan.order.isEmpty)
  }

  func testNoLocalLeavesCachedOrderAlone() {
    let cards = [
      ContinueWatchingLocalOverlay.Card(itemID: 3, isSeries: true, season: 2, video: 1),
      ContinueWatchingLocalOverlay.Card(itemID: 4, isSeries: true, season: 1, video: 8)
    ]
    let plan = ContinueWatchingLocalOverlay.plan(cards: cards, locals: [])
    XCTAssertEqual(plan.order, [3, 4])
    XCTAssertTrue(plan.mutations.isEmpty)
    XCTAssertTrue(plan.hiddenIDs.isEmpty)
  }

  func testFinishedFilmDoesNotHideADifferentCard() {
    let cards = [
      ContinueWatchingLocalOverlay.Card(itemID: 1, isSeries: false, season: nil, video: 1),
      ContinueWatchingLocalOverlay.Card(itemID: 2, isSeries: false, season: nil, video: 1)
    ]
    let locals = [
      local(id: 1, isFinished: true, isSeries: false, updatedAt: 1)
    ]
    let plan = ContinueWatchingLocalOverlay.plan(cards: cards, locals: locals)
    XCTAssertEqual(plan.order, [2])
    XCTAssertEqual(plan.hiddenIDs, [1])
  }

  // MARK: -

  private func local(id: Int,
                     progress: Double? = nil,
                     season: Int? = nil,
                     episode: Int? = nil,
                     isFinished: Bool = false,
                     isSeries: Bool = false,
                     updatedAt: TimeInterval,
                     canInsert: Bool = false) -> ContinueWatchingLocalOverlay.Local {
    ContinueWatchingLocalOverlay.Local(
      itemID: id,
      isSeries: isSeries,
      season: season,
      episode: episode,
      isFinished: isFinished,
      isResumable: !isFinished && progress != nil,
      progress: isFinished ? nil : progress,
      updatedAt: updatedAt,
      canInsert: canInsert
    )
  }
}
