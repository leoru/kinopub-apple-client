//
//  SubtitleRenditionsTests.swift
//
//  Pairing a decided `SubtitleTrack` with the master's own subtitle rendition —
//  what the system player selects off tvOS. Covered without an asset on purpose,
//  see `SubtitleRendition`.
//

import XCTest
@testable import KinoPubBackend

final class SubtitleRenditionsTests: XCTestCase {

  private struct Rendition: SubtitleRendition, Equatable {
    var renditionLanguageCode: String
    var isForcedRendition: Bool = false
  }

  private func tracks(_ languages: [String]) -> [SubtitleTrack] {
    SubtitleTracks.catalog(languages.map {
      Subtitle(lang: $0, shift: 0, embed: false, url: "https://example.com/\($0).srt")
    })
  }

  func testTheOnlyTrackOfItsLanguageMatchesThatRendition() {
    let track = tracks(["eng", "rus"])[1]
    let renditions = [Rendition(renditionLanguageCode: "en"), Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: track, in: renditions), renditions[1])
  }

  /// Three-letter API codes against two-letter HLS tags is the normal case, not an edge.
  func testLanguageCodesAreNormalisedBeforeMatching() {
    let track = tracks(["ukr"])[0]
    let renditions = [Rendition(renditionLanguageCode: "uk")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: track, in: renditions), renditions[0])
  }

  func testTheSecondTrackOfALanguageTakesTheSecondRenditionOfIt() {
    let catalog = tracks(["rus", "eng", "rus"])
    let renditions = [Rendition(renditionLanguageCode: "ru"),
                      Rendition(renditionLanguageCode: "en"),
                      Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[0], in: renditions), renditions[0])
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[2], in: renditions), renditions[2])
  }

  /// A master that carries fewer copies than the API listed still has to land on the
  /// language — and never on signage.
  func testAMissingPositionFallsBackToTheFirstNonForcedOfThatLanguage() {
    // Three Russian subtitles listed by the API, two renditions in the master: the third
    // track has no position to take.
    let catalog = tracks(["rus", "rus", "rus"])
    let renditions = [Rendition(renditionLanguageCode: "ru", isForcedRendition: true),
                      Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[2], in: renditions), renditions[1])
  }

  func testNothingInThatLanguageMeansNoSubtitlesRatherThanAWrongLine() {
    let track = tracks(["rus"])[0]
    let renditions = [Rendition(renditionLanguageCode: "en")]
    XCTAssertNil(SubtitleRenditions.rendition(for: track, in: renditions))
  }
}
