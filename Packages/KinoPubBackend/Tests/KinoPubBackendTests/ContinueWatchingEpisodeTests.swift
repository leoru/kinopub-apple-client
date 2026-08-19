//
//  ContinueWatchingEpisodeTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

/// Daisy Jones & The Six (87940) as the account actually had it: S1E2–E4 watched to the
/// end (`watched: 1`), E5 not (`watched: -1`), and the newest history row is E2 with
/// `time == duration`. Continue Watching offered E2.
final class ContinueWatchingEpisodeTests: XCTestCase {

  func testFinishedHistoryEpisodeIsNotOfferedAgain() {
    let next = ContinueWatchingEpisode.forSeries(
      local: nil,
      history: (season: 1, episode: 2, isFinished: true),
      finishedInSeason: [1, 2, 3, 4],
      watchedCount: 4,
      total: 10
    )
    XCTAssertEqual(next.episode, 5)
    XCTAssertEqual(next.season, 1)
    XCTAssertFalse(next.isResuming)
  }

  /// The one case a resume bar means anything: someone is in the middle of it.
  func testUnfinishedHistoryEpisodeIsResumed() {
    let next = ContinueWatchingEpisode.forSeries(
      local: nil,
      history: (season: 2, episode: 6, isFinished: false),
      finishedInSeason: [1, 2, 3, 4, 5],
      watchedCount: 12,
      total: 23
    )
    XCTAssertEqual(next.episode, 6)
    XCTAssertEqual(next.season, 2)
    XCTAssertTrue(next.isResuming)
  }

  /// This device's own play head wins — the server has not heard about it yet.
  func testLocalProgressBeatsTheServerCount() {
    let next = ContinueWatchingEpisode.forSeries(
      local: (season: 1, episode: 7, isFinished: false),
      history: (season: 1, episode: 2, isFinished: true),
      finishedInSeason: [1, 2],
      watchedCount: 4,
      total: 10
    )
    XCTAssertEqual(next.episode, 7)
    XCTAssertTrue(next.isResuming)
  }

  /// A count from the server survives episodes watched on another device, so when it
  /// is the furthest signal it wins.
  func testWatchedCountLeadsWhenItIsFurthest() {
    let next = ContinueWatchingEpisode.forSeries(
      local: (season: 1, episode: 2, isFinished: true),
      history: (season: 1, episode: 2, isFinished: true),
      finishedInSeason: [1, 2],
      watchedCount: 8,
      total: 10
    )
    XCTAssertEqual(next.episode, 9)
    XCTAssertFalse(next.isResuming)
  }

  /// 🔴 The bug on screen: E1–E4 all watched, E2 replayed most recently, and the
  /// server's own count still said 2. History is ordered by *when*, not by episode
  /// number, so the newest row is not the furthest one.
  func testFurthestFinishedEpisodeWinsOverTheNewestRow() {
    let next = ContinueWatchingEpisode.forSeries(
      local: nil,
      history: (season: 1, episode: 2, isFinished: true),
      finishedInSeason: [1, 2, 3, 4],
      watchedCount: 2,
      total: 10
    )
    XCTAssertEqual(next.episode, 5, "E1–E4 are done; E5 is the first unwatched one")
  }

  /// History is 20 rows deep, so an old E1 may be long gone while E4 is still there —
  /// which is why this takes the maximum rather than looking for the first gap.
  func testTruncatedHistoryStillLandsPastTheFurthestFinished() {
    let next = ContinueWatchingEpisode.forSeries(
      local: nil,
      history: (season: 2, episode: 9, isFinished: true),
      finishedInSeason: [9],
      watchedCount: nil,
      total: nil
    )
    XCTAssertEqual(next.episode, 10)
    XCTAssertEqual(next.season, 2)
  }

  func testStepsPastTheLastSeenEpisodeWithoutACount() {
    let next = ContinueWatchingEpisode.forSeries(
      local: nil,
      history: (season: 3, episode: 4, isFinished: true),
      finishedInSeason: [4],
      watchedCount: nil,
      total: nil
    )
    XCTAssertEqual(next.episode, 5)
    XCTAssertEqual(next.season, 3)
  }

  /// Every episode watched: there is nothing to continue, and the card says so by
  /// having no episode at all.
  func testNothingLeftWhenTheSeriesIsFinished() {
    let next = ContinueWatchingEpisode.forSeries(
      local: nil,
      history: (season: 1, episode: 10, isFinished: true),
      finishedInSeason: [8, 9, 10],
      watchedCount: 10,
      total: 10
    )
    XCTAssertEqual(next, .nothingLeft)
    XCTAssertFalse(next.hasEpisode)
  }

  /// A title with nothing watched and nothing in history — following it is all we know.
  func testNoSignalAtAllOffersNoEpisode() {
    let next = ContinueWatchingEpisode.forSeries(local: nil, history: nil,
                                                 watchedCount: nil, total: 10)
    XCTAssertNil(next.episode)
    XCTAssertFalse(next.isResuming)
  }

  func testOverlayLabelFormatsSeasonAndEpisode() {
    XCTAssertEqual(ContinueWatchingEpisode.overlayLabel(season: 2, episode: 5), "S2, E5")
    XCTAssertEqual(ContinueWatchingEpisode.overlayLabel(season: nil, episode: 3), "E3")
    XCTAssertNil(ContinueWatchingEpisode.overlayLabel(season: 1, episode: nil))
  }
}
