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
}
