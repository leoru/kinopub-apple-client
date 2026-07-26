//
//  PostersAndDurationTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class PostersAndDurationTests: XCTestCase {

  // MARK: - Posters.wideURL

  func testWidePrefersTheExplicitField() {
    let posters = Posters(small: "s", medium: "m", big: "b", wide: "https://x/wide/1.jpg")
    XCTAssertEqual(posters.wideURL, "https://x/wide/1.jpg")
  }

  /// The API serves the same id under `/wide/`, so a missing field is derived.
  func testWideIsDerivedFromBigBySwappingTheSizeSegment() {
    let posters = Posters(small: "https://m.staticpop.net/poster/item/small/124771.jpg",
                          medium: "https://m.staticpop.net/poster/item/medium/124771.jpg",
                          big: "https://m.staticpop.net/poster/item/big/124771.jpg",
                          wide: nil)
    XCTAssertEqual(posters.wideURL, "https://m.staticpop.net/poster/item/wide/124771.jpg")
  }

  func testWideDerivesFromMediumWhenBigIsEmpty() {
    let posters = Posters(small: "",
                          medium: "https://m.staticpop.net/poster/item/medium/9.jpg",
                          big: "",
                          wide: nil)
    XCTAssertEqual(posters.wideURL, "https://m.staticpop.net/poster/item/wide/9.jpg")
  }

  func testWideIsNilWhenNothingUsableIsPresent() {
    XCTAssertNil(Posters(small: "", medium: "", big: "", wide: nil).wideURL)
    XCTAssertNil(Posters(small: "not-a-poster-url", medium: "", big: "", wide: "").wideURL)
  }

  // MARK: - Duration.hoursMinutes

  func testDurationUnderAnHourIsMinutesOnly() {
    XCTAssertEqual(Duration.hoursMinutes(seconds: 49 * 60), "49 min")
  }

  func testDurationOverAnHourShowsBoth() {
    XCTAssertEqual(Duration.hoursMinutes(seconds: 108 * 60), "1 h 48 min")
  }

  func testDurationOnAWholeHourOmitsMinutes() {
    XCTAssertEqual(Duration.hoursMinutes(seconds: 120 * 60), "2 h")
  }

  func testZeroDurationIsEmpty() {
    XCTAssertEqual(Duration.hoursMinutes(seconds: 0), "")
  }

  // MARK: - Duration.compactHoursMinutes

  func testCompactDurationUnderAnHour() {
    XCTAssertEqual(Duration.compactHoursMinutes(seconds: 39 * 60), "39m")
  }

  func testCompactDurationOverAnHour() {
    XCTAssertEqual(Duration.compactHoursMinutes(seconds: 155 * 60), "2h 35m")
  }

  func testCompactDurationOnAWholeHour() {
    XCTAssertEqual(Duration.compactHoursMinutes(seconds: 120 * 60), "2h")
  }

  func testCompactDurationPastADay() {
    XCTAssertEqual(Duration.compact(seconds: 36 * 60 * 60 + 4 * 60), "1d 12h 4m")
  }

  func testCompactWithMinutesUnderAnHour() {
    XCTAssertEqual(Duration.compactWithMinutes(seconds: 39 * 60), "39m")
  }

  func testCompactWithMinutesOverAnHour() {
    XCTAssertEqual(Duration.compactWithMinutes(seconds: 105 * 60), "1h 45m (105 min)")
  }
}
