//
//  SubtitleRenditionsTests.swift
//
//  Pairing a decided `SubtitleTrack` with the master's own subtitle rendition — what the
//  system player is told to show off tvOS, and what a pick in its menu is read back as.
//  Covered without an asset on purpose, see `SubtitleRendition`.
//

import XCTest
@testable import KinoPubBackend

final class SubtitleRenditionsTests: XCTestCase {

  private struct Rendition: SubtitleRendition, Equatable {
    var renditionLanguageCode: String
    var isForcedRendition: Bool = false
    var isCaptioningRendition: Bool = false
  }

  /// kino.pub sends three-letter ids and a URL, and nothing else about a subtitle — the
  /// CC / forced markers are read out of that URL.
  private func tracks(_ files: [(String, String)]) -> [SubtitleTrack] {
    SubtitleTracks.catalog(files.map {
      Subtitle(lang: $0.0, shift: 0, embed: false, url: "https://example.com/\($0.1)")
    })
  }

  private func tracks(_ languages: [String]) -> [SubtitleTrack] {
    tracks(languages.map { ($0, "\($0).srt") })
  }

  // MARK: - Language

  func testTheOnlyTrackOfItsLanguageTakesThatRendition() {
    let catalog = tracks(["eng", "rus"])
    let renditions = [Rendition(renditionLanguageCode: "en"), Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[1], among: catalog, in: renditions),
                   renditions[1])
  }

  /// Three-letter API ids against two-letter HLS tags is the normal case, not an edge —
  /// and both sides go through the same table, so `phi` reaches Filipino.
  func testLanguageCodesAreNormalisedBeforeMatching() {
    for (api, hls) in [("ukr", "uk"), ("fre", "fr"), ("ger", "de"), ("chi", "zh"),
                       ("uzb", "uz"), ("phi", "fil"), ("ron", "ro"), ("kaz", "kk")] {
      let catalog = tracks([api])
      let renditions = [Rendition(renditionLanguageCode: hls)]
      XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[0], among: catalog, in: renditions),
                     renditions[0], "\(api) should match \(hls)")
    }
  }

  /// Their machine-translated Russian is a separate entry in the same list — an item can
  /// carry both, and picking one when the viewer chose the other is exactly the kind of
  /// wrong line this pairing exists to avoid.
  func testMachineTranslatedRussianIsNotTheRussianTrack() {
    let catalog = tracks(["rus", "ai"])
    let renditions = [Rendition(renditionLanguageCode: "ru"), Rendition(renditionLanguageCode: "ai")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[0], among: catalog, in: renditions),
                   renditions[0])
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[1], among: catalog, in: renditions),
                   renditions[1])
    XCTAssertNotEqual(SubtitleTracks.languageKey("ai"), SubtitleTracks.languageKey("rus"))
  }

  func testNothingInThatLanguageMeansNoSubtitlesRatherThanAWrongLine() {
    let catalog = tracks(["rus"])
    XCTAssertNil(SubtitleRenditions.rendition(for: catalog[0],
                                              among: catalog,
                                              in: [Rendition(renditionLanguageCode: "en")]))
  }

  // MARK: - Kind

  func testAPlainTrackNeverLandsOnSignage() {
    let catalog = tracks(["rus"])
    let renditions = [Rendition(renditionLanguageCode: "ru", isForcedRendition: true),
                      Rendition(renditionLanguageCode: "ru", isCaptioningRendition: true)]
    // Neither is the same kind; the captioning one is still dialogue, forced is not.
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[0], among: catalog, in: renditions),
                   renditions[1])
  }

  func testCaptioningAndPlainTracksOfOneLanguageDoNotSwap() {
    let catalog = tracks([("rus", "movie.rus.srt"), ("rus", "movie.rus.sdh.srt")])
    XCTAssertFalse(catalog[0].isCC)
    XCTAssertTrue(catalog[1].isCC)
    let renditions = [Rendition(renditionLanguageCode: "ru", isCaptioningRendition: true),
                      Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[0], among: catalog, in: renditions),
                   renditions[1])
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[1], among: catalog, in: renditions),
                   renditions[0])
  }

  // MARK: - Position, the last discriminator

  func testTwoTracksOfOneLanguageAndKindAreToldApartByPosition() {
    let catalog = tracks([("rus", "one.rus.srt"), ("eng", "one.eng.srt"), ("rus", "two.rus.srt")])
    let renditions = [Rendition(renditionLanguageCode: "ru"),
                      Rendition(renditionLanguageCode: "en"),
                      Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[0], among: catalog, in: renditions),
                   renditions[0])
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[2], among: catalog, in: renditions),
                   renditions[2])
  }

  /// A master carrying fewer copies than the API listed still has to land on the language.
  func testAMissingPositionFallsBackWithinTheLanguage() {
    let catalog = tracks(["rus", "rus", "rus"])
    let renditions = [Rendition(renditionLanguageCode: "ru"), Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[2], among: catalog, in: renditions),
                   renditions[0])
  }

  /// Position is counted inside the language, so another language appearing between two
  /// Russian tracks — or a new language added to the item — moves nothing.
  func testAnUnrelatedLanguageBetweenThemChangesNothing() {
    let catalog = tracks(["rus", "ukr", "eng", "rus"])
    let renditions = [Rendition(renditionLanguageCode: "ru"),
                      Rendition(renditionLanguageCode: "uk"),
                      Rendition(renditionLanguageCode: "en"),
                      Rendition(renditionLanguageCode: "ru")]
    XCTAssertEqual(SubtitleRenditions.rendition(for: catalog[3], among: catalog, in: renditions),
                   renditions[3])
  }

  // MARK: - Reading a pick back

  /// Round trip: every track pairs with a rendition that reads back as the same track —
  /// including the second Russian one, where a value-wise comparison would land on the
  /// first, and the SDH one beside it.
  func testEveryTrackReadsBackAsItself() throws {
    let catalog = tracks([("rus", "one.rus.srt"), ("eng", "one.eng.srt"),
                          ("rus", "two.rus.srt"), ("rus", "two.rus.sdh.srt")])
    let renditions = [Rendition(renditionLanguageCode: "ru"),
                      Rendition(renditionLanguageCode: "en"),
                      Rendition(renditionLanguageCode: "ru"),
                      Rendition(renditionLanguageCode: "ru", isCaptioningRendition: true)]
    for track in catalog {
      let index = try XCTUnwrap(
        SubtitleRenditions.renditionIndex(for: track, among: catalog, in: renditions),
        "no rendition for \(track.displayName)"
      )
      XCTAssertEqual(SubtitleRenditions.track(forRenditionAt: index, among: renditions, in: catalog),
                     track,
                     "\(track.displayName) did not read back as itself")
    }
  }

  func testAPickInALanguageWeNeverListedIsNotForcedOntoATrack() {
    let catalog = tracks(["rus"])
    let renditions = [Rendition(renditionLanguageCode: "ja")]
    XCTAssertNil(SubtitleRenditions.track(forRenditionAt: 0, among: renditions, in: catalog))
  }

  func testAnIndexOutsideTheGroupIsNoTrack() {
    let catalog = tracks(["rus"])
    XCTAssertNil(SubtitleRenditions.track(forRenditionAt: 7,
                                          among: [Rendition(renditionLanguageCode: "ru")],
                                          in: catalog))
  }
}
