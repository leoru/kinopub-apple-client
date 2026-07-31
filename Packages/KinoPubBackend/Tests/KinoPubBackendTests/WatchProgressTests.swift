//
//  WatchProgressTests.swift
//  KinoPubBackendTests
//
//  Exhaustive edge-case coverage for the watched / in-progress / finished classifier.
//

import XCTest
@testable import KinoPubBackend

final class WatchProgressTests: XCTestCase {

  // MARK: No usable duration (live channels, trailers, bad data)

  func testZeroDurationIsUnwatched() {
    let p = WatchProgress(position: 120, duration: 0)
    XCTAssertNil(p.fraction)
    XCTAssertFalse(p.isFinished)
    XCTAssertFalse(p.hasStarted)
    XCTAssertFalse(p.isResumable)
    XCTAssertEqual(p.state, .unwatched)
  }

  func testNonFiniteDurationIsUnwatched() {
    for d in [Double.nan, .infinity, -.infinity] {
      let p = WatchProgress(position: 120, duration: d)
      XCTAssertNil(p.fraction, "duration \(d)")
      XCTAssertEqual(p.state, .unwatched, "duration \(d)")
      XCTAssertFalse(p.isFinished)
    }
  }

  func testNegativeDurationIsUnwatched() {
    let p = WatchProgress(position: 50, duration: -100)
    XCTAssertNil(p.fraction)
    XCTAssertEqual(p.state, .unwatched)
  }

  // MARK: Not started

  func testZeroPositionIsUnwatched() {
    let p = WatchProgress(position: 0, duration: 3600)
    XCTAssertEqual(p.fraction, 0)
    XCTAssertEqual(p.state, .unwatched)
    XCTAssertFalse(p.isResumable)
  }

  func testNegativePositionIsUnwatchedAndClampsFractionToZero() {
    let p = WatchProgress(position: -30, duration: 3600)
    XCTAssertEqual(p.fraction, 0)
    XCTAssertEqual(p.state, .unwatched)
  }

  func testBelowStartFloorIsUnwatched() {
    // 5s into an hour — an accidental tap, should not appear in Continue Watching.
    let p = WatchProgress(position: 5, duration: 3600)
    XCTAssertFalse(p.hasStarted)
    XCTAssertEqual(p.state, .unwatched)
    XCTAssertFalse(p.isResumable)
    XCTAssertEqual(p.fraction ?? -1, 5.0 / 3600.0, accuracy: 1e-9)
  }

  func testExactlyAtStartFloorIsInProgress() {
    let p = WatchProgress(position: WatchProgress.startedSeconds, duration: 3600)
    XCTAssertTrue(p.hasStarted)
    XCTAssertTrue(p.isResumable)
    if case .inProgress = p.state {} else { XCTFail("expected inProgress, got \(p.state)") }
  }

  // MARK: In progress

  func testMidwayIsInProgressWithFraction() {
    let p = WatchProgress(position: 1800, duration: 3600)
    XCTAssertEqual(p.fraction, 0.5)
    XCTAssertTrue(p.isResumable)
    XCTAssertFalse(p.isFinished)
    XCTAssertEqual(p.state, .inProgress(0.5))
  }

  // MARK: Finished (credits)

  func testNearEndWithinToleranceIsFinished() {
    // 2h movie: tolerance caps at 180s. 5s before the end → finished.
    let p = WatchProgress(position: 7200 - 5, duration: 7200)
    XCTAssertTrue(p.isFinished)
    XCTAssertEqual(p.state, .finished)
    XCTAssertFalse(p.isResumable)
  }

  func testJustBeforeToleranceIsStillInProgress() {
    // 2h movie, tolerance 180s. At 7200-200 = 7000 (>180 left) → still in progress.
    let p = WatchProgress(position: 7000, duration: 7200)
    XCTAssertFalse(p.isFinished)
    XCTAssertTrue(p.isResumable)
  }

  func testExactlyAtDurationIsFinished() {
    let p = WatchProgress(position: 3600, duration: 3600)
    XCTAssertTrue(p.isFinished)
    XCTAssertEqual(p.fraction, 1)
    XCTAssertEqual(p.state, .finished)
  }

  func testPastDurationIsFinishedAndFractionClampedToOne() {
    // Rounding / over-report should never read >1 or flip back to in-progress.
    let p = WatchProgress(position: 3650, duration: 3600)
    XCTAssertTrue(p.isFinished)
    XCTAssertEqual(p.fraction, 1)
    XCTAssertEqual(p.state, .finished)
  }

  // MARK: End-tolerance shape

  func testEndToleranceFlooredAndCappedForNormalRuntimes() {
    // 8% of runtime, floored at 60s, capped at 180s.
    XCTAssertEqual(WatchProgress.endTolerance(forDuration: 7200), 180)   // 8% = 576 → cap 180
    XCTAssertEqual(WatchProgress.endTolerance(forDuration: 1800), 144)   // 8% = 144 (within band)
    XCTAssertEqual(WatchProgress.endTolerance(forDuration: 600), 60)     // 8% = 48 → floor 60
  }

  func testEndToleranceNeverExceedsHalfRuntimeForShortClips() {
    // A 60s clip: byFraction would floor to 60, but the half-runtime cap brings it to 30.
    XCTAssertEqual(WatchProgress.endTolerance(forDuration: 60), 30)
  }

  func testShortClipClassification() {
    // 60s clip → finished tolerance is 30s (last half).
    XCTAssertEqual(WatchProgress(position: 40, duration: 60).state, .finished)   // ≥ 30 left-point
    XCTAssertTrue(WatchProgress(position: 20, duration: 60).isResumable)         // started, <30
    XCTAssertEqual(WatchProgress(position: 5, duration: 60).state, .unwatched)   // below start floor
  }

  // MARK: Continue-watching gate

  func testIsResumableOnlyForInProgress() {
    XCTAssertFalse(WatchProgress(position: 0, duration: 3600).isResumable)        // unwatched
    XCTAssertTrue(WatchProgress(position: 1800, duration: 3600).isResumable)      // in progress
    XCTAssertFalse(WatchProgress(position: 3599, duration: 3600).isResumable)     // finished
    XCTAssertFalse(WatchProgress(position: 100, duration: 0).isResumable)         // live
  }
}
