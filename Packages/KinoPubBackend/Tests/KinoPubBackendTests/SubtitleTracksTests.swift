//
//  SubtitleTracksTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class SubtitleTracksTests: XCTestCase {

  private func subtitle(_ lang: String, _ url: String = "") -> Subtitle {
    Subtitle(lang: lang, shift: 0, embed: false, url: url)
  }

  // MARK: - Language keys

  func testThreeLetterAndRegionCodesCollapseToTheSameLanguage() {
    XCTAssertTrue(SubtitleTracks.matches(language: "en", "eng"))
    XCTAssertTrue(SubtitleTracks.matches(language: "EN-US", "eng"))
    XCTAssertTrue(SubtitleTracks.matches(language: "ru", "rus"))
    XCTAssertFalse(SubtitleTracks.matches(language: "ru", "ukr"))
  }

  // MARK: - CC and forced detection

  func testCCMarkersAreMatchedAsWholeWordsOnly() {
    XCTAssertTrue(SubtitleTracks.looksLikeCC(subtitle("eng", "https://x/s01e01.eng.sdh.srt")))
    XCTAssertTrue(SubtitleTracks.looksLikeCC(subtitle("eng", "https://x/s01e01-cc-track.srt")))
    XCTAssertFalse(SubtitleTracks.looksLikeCC(subtitle("eng", "https://x/succinct.srt")))
  }

  func testHindiIsNotMistakenForHearingImpaired() {
    XCTAssertFalse(SubtitleTracks.looksLikeCC(subtitle("hi", "https://x/s01e01.hindi.srt")))
    XCTAssertTrue(SubtitleTracks.looksLikeCC(subtitle("eng", "https://x/s01e01.hi.srt")))
  }

  func testForcedIsItsOwnFlagRatherThanCC() {
    let forced = subtitle("eng", "https://x/s01e01.forced.srt")
    XCTAssertTrue(SubtitleTracks.isForced(forced))
    XCTAssertFalse(SubtitleTracks.looksLikeCC(forced))
    XCTAssertFalse(SubtitleTracks.isForced(subtitle("eng", "https://x/enforced.srt")))
  }

  // MARK: - Defaults

  func testForcedTracksAreNeverTheDefault() {
    let tracks = SubtitleTracks.catalog([
      subtitle("eng", "https://x/s01e01.forced.srt"),
      subtitle("eng", "https://x/s01e01.full.srt")
    ])
    let chosen = SubtitleTracks.preferred(language: "en", in: tracks, preferNonCC: true)
    XCTAssertEqual(chosen?.url, "https://x/s01e01.full.srt")
  }

  func testDefaultOnlyForcedInThatLanguageMeansNoDefault() {
    let tracks = SubtitleTracks.catalog([subtitle("eng", "https://x/s01e01.forced.srt")])
    XCTAssertNil(SubtitleTracks.preferred(language: "en", in: tracks, preferNonCC: true))
  }

  func testNonCCIsPreferredButCCStillWinsOverNothing() {
    let mixed = SubtitleTracks.catalog([
      subtitle("eng", "https://x/e01.sdh.srt"),
      subtitle("eng", "https://x/e01.srt")
    ])
    XCTAssertEqual(SubtitleTracks.preferred(language: "en", in: mixed, preferNonCC: true)?.url,
                   "https://x/e01.srt")

    let onlyCC = SubtitleTracks.catalog([subtitle("eng", "https://x/e01.sdh.srt")])
    XCTAssertEqual(SubtitleTracks.preferred(language: "en", in: onlyCC, preferNonCC: true)?.url,
                   "https://x/e01.sdh.srt")
  }

  func testTrackWithASidecarURLWinsOverAnEmbeddedOne() {
    let tracks = SubtitleTracks.catalog([subtitle("rus"), subtitle("rus", "https://x/e01.ru.srt")])
    XCTAssertEqual(SubtitleTracks.preferred(language: "ru", in: tracks, preferNonCC: true)?.url,
                   "https://x/e01.ru.srt")
  }

  // MARK: - Remembering a choice across episodes

  func testARememberedChoiceIsFoundOnTheNextEpisode() {
    let episodeOne = SubtitleTracks.catalog([
      subtitle("rus", "https://x/s01e01.rus.srt"),
      subtitle("eng", "https://x/s01e01.eng.srt"),
      subtitle("eng", "https://x/s01e01.eng.sdh.srt")
    ])
    let chosen = episodeOne[2]
    XCTAssertTrue(chosen.isCC)

    let episodeTwo = SubtitleTracks.catalog([
      subtitle("eng", "https://x/s01e02.eng.srt"),
      subtitle("eng", "https://x/s01e02.eng.sdh.srt"),
      subtitle("rus", "https://x/s01e02.rus.srt")
    ])
    let resolved = SubtitleTracks.resolve(chosen.reference, in: episodeTwo)
    XCTAssertEqual(resolved?.url, "https://x/s01e02.eng.sdh.srt")
  }

  func testTheSecondTrackOfALanguageStaysTheSecondOne() {
    let episodeOne = SubtitleTracks.catalog([
      subtitle("rus", "https://x/s01e01.rus.dub.srt"),
      subtitle("rus", "https://x/s01e01.rus.sub.srt")
    ])
    let resolved = SubtitleTracks.resolve(episodeOne[1].reference, in: SubtitleTracks.catalog([
      subtitle("rus", "https://x/s01e02.rus.dub.srt"),
      subtitle("rus", "https://x/s01e02.rus.sub.srt")
    ]))
    XCTAssertEqual(resolved?.url, "https://x/s01e02.rus.sub.srt")
  }

  func testARememberedChoiceFallsBackWithinItsLanguage() {
    let reference = SubtitleTrackReference(lang: "eng", isCC: true, ordinal: 3)
    let tracks = SubtitleTracks.catalog([subtitle("eng", "https://x/s01e09.eng.srt")])
    XCTAssertEqual(SubtitleTracks.resolve(reference, in: tracks)?.url, "https://x/s01e09.eng.srt")
  }

  func testARememberedLanguageThatIsGoneResolvesToNothing() {
    let reference = SubtitleTrackReference(lang: "ukr", isCC: false, ordinal: 0)
    let tracks = SubtitleTracks.catalog([subtitle("eng", "https://x/s01e09.eng.srt")])
    XCTAssertNil(SubtitleTracks.resolve(reference, in: tracks))
  }

  // MARK: - Naming

  func testDisplayNamesSeparateTracksOfTheSameLanguage() {
    let tracks = SubtitleTracks.catalog([
      subtitle("eng", "https://x/e01.eng.srt"),
      subtitle("eng", "https://x/e01.eng.sdh.srt"),
      subtitle("eng", "https://x/e01.eng.forced.srt")
    ])
    // The language name itself is localized, so only the badges are asserted here.
    XCTAssertEqual(tracks[0].displayName, LanguageNames.name(for: "eng"))
    XCTAssertTrue(tracks[1].displayName.hasSuffix(" (CC · 2)"), tracks[1].displayName)
    XCTAssertTrue(tracks[2].displayName.hasSuffix(" (Forced · 3)"), tracks[2].displayName)
  }
}
