//
//  HistoryEntryTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class HistoryEntryTests: XCTestCase {

  private func entry(snumber: Int?, number: Int?, time: Double? = nil, duration: Int? = nil) -> HistoryEntry {
    HistoryEntry(item: .init(id: 1),
                 media: .init(number: number, snumber: snumber, duration: duration),
                 time: time,
                 lastSeen: 1_000)
  }

  /// Films come back as snumber 0 / number 1, which must not render as "S0, E1".
  func testFilmIsNotAnEpisode() {
    XCTAssertFalse(entry(snumber: 0, number: 1).isEpisode)
  }

  func testEpisodeIsAnEpisode() {
    XCTAssertTrue(entry(snumber: 2, number: 5).isEpisode)
  }

  func testMissingNumbersAreNotAnEpisode() {
    XCTAssertFalse(entry(snumber: nil, number: nil).isEpisode)
    XCTAssertFalse(entry(snumber: 1, number: nil).isEpisode)
  }

  func testProgressIsPositionOverDuration() {
    XCTAssertEqual(entry(snumber: 1, number: 1, time: 600, duration: 2400).progress ?? 0,
                   0.25,
                   accuracy: 0.001)
  }

  func testProgressIsNilWhenFinished() {
    // Past duration → finished → not resumable, so Continue Watching gets no bar.
    XCTAssertNil(entry(snumber: 1, number: 1, time: 3000, duration: 2400).progress)
  }

  func testProgressIsNilWithoutUsableNumbers() {
    XCTAssertNil(entry(snumber: 1, number: 1, time: nil, duration: 2400).progress)
    XCTAssertNil(entry(snumber: 1, number: 1, time: 600, duration: nil).progress)
    XCTAssertNil(entry(snumber: 1, number: 1, time: 600, duration: 0).progress)
  }

  /// The real payload shape, so a field rename upstream fails loudly here.
  func testDecodesTheDocumentedPayload() throws {
    let json = """
    {
      "history": [{
        "time": 1383,
        "counter": 3,
        "first_seen": 1783444874,
        "last_seen": 1784663240,
        "item": {
          "id": 82852,
          "type": "serial",
          "title": "Пантеон / Pantheon",
          "posters": {
            "small": "s.jpg", "medium": "m.jpg", "big": "b.jpg", "wide": "w.jpg"
          }
        },
        "media": {
          "id": 971194, "number": 5, "snumber": 2,
          "thumbnail": "t.jpg", "title": "Yair", "duration": 2535
        }
      }]
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(HistoryData.self, from: json)
    let first = try XCTUnwrap(decoded.history.first)

    XCTAssertEqual(first.item.id, 82852)
    XCTAssertEqual(first.item.posters?.wide, "w.jpg")
    XCTAssertEqual(first.media?.snumber, 2)
    XCTAssertEqual(first.media?.number, 5)
    XCTAssertEqual(first.media?.thumbnail, "t.jpg")
    XCTAssertEqual(first.media?.duration, 2535)
    XCTAssertTrue(first.isEpisode)
    XCTAssertEqual(first.lastSeenDate, Date(timeIntervalSince1970: 1784663240))
  }

  /// Presentation-only fields must never cost us the row.
  func testDecodesWithOnlyAnItemID() throws {
    let json = #"{"history": [{"item": {"id": 7}}]}"#.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(HistoryData.self, from: json)

    XCTAssertEqual(decoded.history.first?.item.id, 7)
    XCTAssertNil(decoded.history.first?.media)
    XCTAssertNil(decoded.history.first?.lastSeenDate)
  }
}
