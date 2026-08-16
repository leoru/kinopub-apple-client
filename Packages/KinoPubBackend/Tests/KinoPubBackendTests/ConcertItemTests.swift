//
//  ConcertItemTests.swift
//
//  `type: "concert"` — item 126187 ("Schiller / Nature One"), captured from the PWA
//  2026-08-16. `Fixtures/item_126187_concert.json` is that response with the signed CDN
//  URLs replaced, the plot shortened and one of three files dropped. Everything asserted
//  on is verbatim.
//
//  A concert is not a shape we had ever decoded, and it is the first payload seen with
//  `imdb: null` *and* `imdb_rating: 8.1` — a rating with no id behind it.
//

import XCTest
@testable import KinoPubBackend

final class ConcertItemTests: XCTestCase {

  private func item() throws -> MediaItem {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "item_126187_concert",
                                              withExtension: "json",
                                              subdirectory: "Fixtures"))
    return try JSONDecoder().decode(SingleItemData<MediaItem>.self,
                                    from: Data(contentsOf: url)).item
  }

  func testConcertDecodes() throws {
    let item = try item()
    XCTAssertEqual(item.id, 126187)
    XCTAssertEqual(item.type, "concert")
    XCTAssertEqual(item.videos?.count, 1)
    XCTAssertFalse(item.isSeries)
  }

  /// The one that would have crashed a stricter model: a rating exists without an id.
  /// Both `imdb` and `kinopoisk` are null here while both ratings are populated, so an
  /// external-id lookup must never be gated on "we have a rating".
  func testRatingsSurviveNullExternalIds() throws {
    let item = try item()
    XCTAssertNil(item.imdb)
    XCTAssertNil(item.kinopoisk)
    XCTAssertEqual(item.imdbRating, 8.1)
    XCTAssertEqual(item.kinopoiskRating, 7.295)
  }

  /// `subtype` is an empty string here, not absent and not `"null"` — the multi check
  /// must not trip on it, and neither must the tag strip.
  func testEmptySubtypeIsNotAVersionMarker() throws {
    let item = try item()
    XCTAssertEqual(item.subtype, "")
    XCTAssertFalse(item.isMultiVersion)
    XCTAssertTrue(item.playbackVariants.isEmpty, "One video is not a choice")
    XCTAssertNil(item.contentSubtypeTitleKey)
    XCTAssertNil(item.contentSubtypeRaw)
  }

  /// No trailer on this one — the hero's Trailer button has to cope with `nil`.
  func testTrailerIsAbsent() throws {
    XCTAssertNil(try item().trailer)
    XCTAssertNil(try item().trailerURL)
  }

  /// Single video, so `total == average` and the runtime reads correctly either way.
  func testRuntime() throws {
    let item = try item()
    XCTAssertEqual(item.duration.total, 5257)
    XCTAssertEqual(item.duration.average, 5257)
    XCTAssertTrue(item.releaseLine.contains(Duration.compact(seconds: 5257)))
  }

  /// `audios[].author` is null on an original-language track — the field is only filled
  /// for dubs, and `AudioTracks` must not require it.
  func testOriginalAudioHasNoAuthor() throws {
    let tracks = try item().audioTracks
    XCTAssertEqual(tracks.count, 1)
  }

  /// **Known gap, deliberately asserted so it is not forgotten:** `tracklist` is in the
  /// payload (6 entries here) and `MediaItem` does not decode it at all, so the concert
  /// setlist is dropped on the floor. See `docs/providers/kinopub/video.md`.
  func testTracklistIsNotDecodedYet() throws {
    let mirror = Mirror(reflecting: try item())
    XCTAssertFalse(mirror.children.contains { $0.label == "tracklist" },
                   "tracklist is now decoded — model the setlist and delete this test")
  }
}
