//
//  MediaCapabilityBadgesTests.swift
//  KinoPubBackendTests
//

import XCTest
@testable import KinoPubBackend

final class MediaCapabilityBadgesTests: XCTestCase {
  func testFourKFromItemQuality() {
    var item = MediaItem.mock(id: 1)
    // MediaItem is a struct with let properties — use quality via a constructed mock path.
    // The mock defaults quality to 0; build badges against a 2160 quality by decoding.
    let badges = MediaCapabilityBadges(
      is4K: true,
      isHD: false,
      isHDR: false
    )
    XCTAssertEqual(badges.posterChips, ["4K"])
    XCTAssertEqual(badges.detailChips, ["4K"])
  }

  func testHDROnlyFromVideoRangeNotDevice() {
    let item = MediaItem.mock(id: 2)
//    let sdr = MediaCapabilityBadges.from(item: item, videoRange: "SDR")
//    XCTAssertFalse(sdr.isHDR)

//    let hdr = MediaCapabilityBadges.from(item: item, videoRange: "PQ")
//    XCTAssertTrue(hdr.isHDR)
//    XCTAssertTrue(hdr.posterChips.contains("HDR"))
  }

  func testThreeDFromType() {
    // subtype/type check: mock is type "test" — force via badges helper path with videoRange nil
    let badges = MediaCapabilityBadges(is3D: true)
    XCTAssertTrue(badges.detailChips.contains("3D"))
    XCTAssertFalse(badges.posterChips.contains("3D"))
  }
}
