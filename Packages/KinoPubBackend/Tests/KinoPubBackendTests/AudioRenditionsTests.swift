//
//  AudioRenditionsTests.swift
//
//  The bridge between what `TrackResolver` decides and what the player can select.
//  Covered without an asset on purpose — see `AudioRendition`.
//

import XCTest
@testable import KinoPubBackend

final class AudioRenditionsTests: XCTestCase {

  private struct Rendition: AudioRendition, Equatable {
    var renditionName: String
    var renditionLanguageCode: String = "ru"
    var describesVideoForAccessibility: Bool = false
  }

  private func track(_ lang: String,
                     _ typeId: Int,
                     _ studio: String? = nil,
                     index: Int = 0) -> AudioTrackInfo {
    let titles = [1: "Дубляж", 2: "Многоголосый", 3: "Двухголосый", 6: "Оригинал"]
    return AudioTrackInfo(lang: lang,
                          typeId: typeId,
                          typeTitle: titles[typeId],
                          authorTitle: studio,
                          index: index)
  }

  // MARK: - Finding the rendition for a decided track

  func testAnExactLabelWins() {
    let lostfilm = track("ru", 2, "LostFilm")
    let renditions = [Rendition(renditionName: "Английский ∙ Оригинал", renditionLanguageCode: "en"),
                      Rendition(renditionName: AudioTracks.baseLabel(lostfilm))]
    XCTAssertEqual(AudioRenditions.rendition(for: lostfilm, in: renditions, apiTracks: [lostfilm]),
                   renditions[1])
  }

  /// HLS forbids two identical `NAME=` in one group, so our labeller uniques them. The
  /// suffixed rendition is still the one the track means.
  func testASuffixedDuplicateStillMatches() {
    let lostfilm = track("ru", 2, "LostFilm")
    let label = AudioTracks.baseLabel(lostfilm)
    let renditions = [Rendition(renditionName: "\(label) ∙ 2")]
    XCTAssertEqual(AudioRenditions.rendition(for: lostfilm, in: renditions, apiTracks: [lostfilm]),
                   renditions[0])
  }

  /// The whole point of labelling: two Russian dubs must not be interchangeable.
  func testTwoDubsOfOneLanguageDoNotCollide() {
    let lostfilm = track("ru", 2, "LostFilm", index: 0)
    let kuraj = track("ru", 2, "Кураж-Бамбей", index: 1)
    let apiTracks = [lostfilm, kuraj]
    let renditions = [Rendition(renditionName: AudioTracks.baseLabel(lostfilm)),
                      Rendition(renditionName: AudioTracks.baseLabel(kuraj))]

    XCTAssertEqual(AudioRenditions.rendition(for: kuraj, in: renditions, apiTracks: apiTracks),
                   renditions[1])
  }

  /// A label that is a prefix of another must not swallow it: "Русский ∙ Дубляж" is not
  /// "Русский ∙ Дубляж, LostFilm".
  func testAPrefixOfALongerLabelIsNotAMatch() {
    let anonymous = track("ru", 1)
    let studio = track("ru", 1, "LostFilm")
    let renditions = [Rendition(renditionName: AudioTracks.baseLabel(studio))]
    XCTAssertNil(AudioRenditions.rendition(for: anonymous, in: renditions, apiTracks: [anonymous]))
  }

  func testAMissingRenditionIsNotInvented() {
    let syenduk = track("ru", 3, "Сыендук")
    let renditions = [Rendition(renditionName: "Английский ∙ Оригинал", renditionLanguageCode: "en")]
    XCTAssertNil(AudioRenditions.rendition(for: syenduk, in: renditions, apiTracks: [syenduk]))
  }

  // MARK: - The synthesised menu

  func testWithoutAPITracksTheMenuIsBuiltFromTheRenditions() {
    let renditions = [
      Rendition(renditionName: "Русский ∙ Дубляж, Мосфильм"),
      Rendition(renditionName: "Japanese", renditionLanguageCode: "ja"),
      Rendition(renditionName: "Описание", describesVideoForAccessibility: true)
    ]
    let menu = AudioRenditions.menu(from: renditions)

    XCTAssertEqual(menu.count, 3)
    XCTAssertEqual(menu[0].kindRank, 0, "the dub kind is readable from the name")
    XCTAssertEqual(menu[0].signature.studio, "Мосфильм", "display keeps the source's own case")
    XCTAssertEqual(menu[1].languageKey, "ja")
    XCTAssertTrue(menu[2].isAudioDescription)
    XCTAssertEqual(menu.map(\.index), [0, 1, 2], "index is the rendition's position")
  }

  func testASynthesisedTrackIsMatchedBackByPosition() {
    let renditions = [Rendition(renditionName: "One"),
                      Rendition(renditionName: "Two"),
                      Rendition(renditionName: "Three")]
    let menu = AudioRenditions.menu(from: renditions)
    XCTAssertEqual(AudioRenditions.rendition(for: menu[2], in: renditions, apiTracks: []),
                   renditions[2])
  }

  func testASynthesisedIndexPastTheEndFindsNothing() {
    let renditions = [Rendition(renditionName: "One")]
    let stale = track("ru", 2, "LostFilm", index: 7)
    XCTAssertNil(AudioRenditions.rendition(for: stale, in: renditions, apiTracks: []))
  }

  // MARK: - Writing down what played

  func testTheAPIRowIsPreferredWhenTheRenditionMapsBack() {
    let syenduk = track("ru", 3, "Сыендук")
    let rendition = Rendition(renditionName: AudioTracks.baseLabel(syenduk))
    XCTAssertEqual(AudioRenditions.signature(for: rendition, apiTracks: [syenduk]),
                   syenduk.signature)
  }

  func testASuffixedRenditionStillResolvesToItsAPIRow() {
    let syenduk = track("ru", 3, "Сыендук")
    let rendition = Rendition(renditionName: "\(AudioTracks.baseLabel(syenduk)) ∙ 2")
    XCTAssertEqual(AudioRenditions.signature(for: rendition, apiTracks: [syenduk]),
                   syenduk.signature)
  }

  /// No API metadata at all — kind and studio are read out of the rendition's own name so
  /// the choice is still remembered as something more specific than "Russian".
  func testWithoutAnAPIRowTheNameIsRead() {
    let rendition = Rendition(renditionName: "Русский ∙ Двухголосый, Jaskier")
    let signature = AudioRenditions.signature(for: rendition, apiTracks: [])

    XCTAssertEqual(signature.languageKey, "ru")
    XCTAssertEqual(signature.kindRank, 2)
    XCTAssertEqual(signature.studio, "Jaskier", "display keeps the source's own case")
  }

  func testAnUnlabelledRenditionStillCarriesItsLanguage() {
    let rendition = Rendition(renditionName: "Audio", renditionLanguageCode: "en")
    let signature = AudioRenditions.signature(for: rendition, apiTracks: [])
    XCTAssertEqual(signature.languageKey, "en")
    XCTAssertEqual(signature.kindRank, AudioTracks.kindRankUnknown)
    XCTAssertNil(signature.studio)
  }

  /// A rendition whose name matches nothing must not borrow another dub's identity.
  func testAnUnrelatedRenditionDoesNotBorrowAnAPIRow() {
    let syenduk = track("ru", 3, "Сыендук")
    let rendition = Rendition(renditionName: "Русский ∙ Дубляж, Мосфильм")
    XCTAssertNotEqual(AudioRenditions.signature(for: rendition, apiTracks: [syenduk]),
                      syenduk.signature)
  }
}
