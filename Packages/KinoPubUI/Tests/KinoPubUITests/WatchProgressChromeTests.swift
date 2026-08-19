import XCTest
@testable import KinoPubUI
import KinoPubBackend

final class LandscapeTimeBadgeTests: XCTestCase {

  func testWatchedFlagBeatsAHighFraction() {
    let badge = LandscapeTimeBadge(durationSeconds: 7200, progress: 0.5, isWatched: true)
    guard case .watched = badge?.kind else {
      return XCTFail("expected watched, got \(String(describing: badge?.kind))")
    }
  }

  /// 93% of a two-hour title is still inside `WatchProgress`'s in-progress window
  /// (finished only in the last 180s ≈ 2.5%). The old 0.95 chip called this watched.
  func testNinetyThreePercentIsStillInProgress() {
    let watch = WatchProgress(position: 0.93 * 7200, duration: 7200)
    XCTAssertTrue(watch.isResumable)
    let badge = LandscapeTimeBadge(
      durationSeconds: 7200,
      progress: watch.resumeFraction,
      isWatched: false
    )
    guard case .inProgress = badge?.kind else {
      return XCTFail("expected inProgress, got \(String(describing: badge?.kind))")
    }
  }

  /// 10s into an hour is started. The old 0.02 floor hid the chip until ~72s.
  func testJustStartedIsInProgress() {
    let watch = WatchProgress(position: WatchProgress.startedSeconds, duration: 3600)
    let badge = LandscapeTimeBadge(
      durationSeconds: 3600,
      progress: watch.resumeFraction,
      isWatched: false
    )
    guard case .inProgress = badge?.kind else {
      return XCTFail("expected inProgress, got \(String(describing: badge?.kind))")
    }
  }

  func testNilProgressIsUnwatched() {
    let badge = LandscapeTimeBadge(durationSeconds: 3600, progress: nil, isWatched: false)
    guard case .unwatched = badge?.kind else {
      return XCTFail("expected unwatched, got \(String(describing: badge?.kind))")
    }
  }
}

final class TVUIKitMediaItemStatusTests: XCTestCase {

  func testResumeFractionPaintsInProgressWithoutAPercentFloor() {
    let watch = WatchProgress(position: WatchProgress.startedSeconds, duration: 3600)
    let card = MediaCard(id: 1, posterURL: "", title: "A",
                         progress: watch.resumeFraction,
                         video: 1)
    let status = TVUIKitMediaItem.status(for: card)
    guard case .inProgress(let value) = status else {
      return XCTFail("expected inProgress, got \(status)")
    }
    XCTAssertEqual(value, watch.resumeFraction)
  }

  func testWatchedIsWatchedEvenWithAStaleFraction() {
    let card = MediaCard(id: 1, posterURL: "", title: "A",
                         progress: 0.5,
                         video: 1,
                         isWatched: true)
    XCTAssertEqual(TVUIKitMediaItem.status(for: card), .watched)
  }

  func testSeriesWithoutAChosenVideoDoesNotPaintAResumeBar() {
    let card = MediaCard(id: 1, posterURL: "", title: "A",
                         progress: 0.5,
                         isSeries: true)
    XCTAssertEqual(TVUIKitMediaItem.status(for: card), .ready)
  }
}
