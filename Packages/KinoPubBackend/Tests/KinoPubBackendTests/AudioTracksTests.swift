//
//  AudioTracksTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class AudioTracksTests: XCTestCase {

  private let preferredENThenRU = ["en-US", "ru-RU"]

  private func track(lang: String,
                     typeId: Int,
                     typeTitle: String,
                     author: String? = nil,
                     channels: Int = 2,
                     codec: String = "aac",
                     index: Int,
                     ad: Bool = false) -> AudioTrackInfo {
    AudioTrackInfo(lang: lang,
                   typeId: typeId,
                   typeTitle: typeTitle,
                   typeShortTitle: nil,
                   authorTitle: author,
                   channels: channels,
                   codec: codec,
                   index: index,
                   isAudioDescription: ad)
  }

  /// Spider-Noir episode 1 shape, shuffled so API order cannot accidentally pass.
  private var spiderNoir: [AudioTrackInfo] {
    [
      track(lang: "rus", typeId: 2, typeTitle: "Многоголосый", author: "NewStudio", channels: 6, index: 1),
      track(lang: "rus", typeId: 1, typeTitle: "Дубляж", author: "Red Head Sound", index: 2),
      track(lang: "rus", typeId: 1, typeTitle: "Дубляж", author: nil, index: 3),
      track(lang: "rus", typeId: 1, typeTitle: "Дубляж", author: "DM", index: 4),
      track(lang: "rus", typeId: 2, typeTitle: "Многоголосый", author: "LostFilm", index: 5),
      track(lang: "rus", typeId: 2, typeTitle: "Многоголосый", author: nil, index: 6),
      track(lang: "rus", typeId: 2, typeTitle: "Многоголосый", author: "TVShows", channels: 6, index: 7),
      track(lang: "rus", typeId: 2, typeTitle: "Многоголосый", author: "GoLTFilm", index: 8),
      track(lang: "rus", typeId: 3, typeTitle: "Двухголосый", author: "Кубик в Кубе", index: 9),
      track(lang: "rus", typeId: 5, typeTitle: "Авторский", author: "М. Яроцкий", channels: 6, index: 10),
      track(lang: "ukr", typeId: 2, typeTitle: "Многоголосый", author: "Цікава Ідея", channels: 6, index: 11),
      track(lang: "ukr", typeId: 2, typeTitle: "Многоголосый", author: "DniproFilm", index: 12),
      track(lang: "ukr", typeId: 3, typeTitle: "Двухголосый", author: nil, channels: 6, index: 13),
      track(lang: "eng", typeId: 6, typeTitle: "Оригинал", author: nil, channels: 6, index: 14),
      track(lang: "rus", typeId: 2, typeTitle: "Многоголосый", author: "NewStudio",
            channels: 6, codec: "ac3", index: 15)
    ]
  }

  // MARK: - Sort ladder

  func testPreferredLanguagesComeFirstThenAlphabetical() {
    let sorted = AudioTracks.sort(spiderNoir, preferredLanguages: preferredENThenRU)
    XCTAssertEqual(sorted.map(\.lang),
                   ["eng",
                    "rus", "rus", "rus", "rus", "rus", "rus", "rus", "rus", "rus", "rus", "rus",
                    "ukr", "ukr", "ukr"])
  }

  func testWithinLanguageKindIsDubThenMultiThenTwoThenAuthor() {
    let sorted = AudioTracks.sort(spiderNoir, preferredLanguages: preferredENThenRU)
    let rus = sorted.filter { $0.lang == "rus" }
    XCTAssertEqual(rus.map(\.typeId),
                   [1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 5])
  }

  func testStudiosSortAlphabeticallyWithAnonymousLast() {
    let sorted = AudioTracks.sort(spiderNoir, preferredLanguages: preferredENThenRU)
    let rusDub = sorted.filter { $0.lang == "rus" && $0.typeId == 1 }
    XCTAssertEqual(rusDub.map { $0.authorTitle ?? "" },
                   ["DM", "Red Head Sound", ""])

    let rusMvo = sorted.filter { $0.lang == "rus" && $0.typeId == 2 }
    XCTAssertEqual(rusMvo.map { $0.authorTitle ?? "" },
                   ["GoLTFilm", "LostFilm", "NewStudio", "NewStudio", "TVShows", ""])
  }

  func testAudioDescriptionSortsAfterRegularInSameLanguage() {
    let tracks = [
      track(lang: "eng", typeId: 6, typeTitle: "Оригинал", index: 1, ad: true),
      track(lang: "eng", typeId: 6, typeTitle: "Оригинал", index: 2, ad: false)
    ]
    let sorted = AudioTracks.sort(tracks, preferredLanguages: ["en"])
    XCTAssertEqual(sorted.map(\.isAudioDescription), [false, true])
  }

  func testDefaultPickIsFirstUnderTheLadder() {
    let sorted = AudioTracks.sort(spiderNoir, preferredLanguages: preferredENThenRU)
    XCTAssertEqual(sorted.first?.lang, "eng")
    XCTAssertEqual(sorted.first?.typeId, 6)
  }

  // MARK: - Labels

  func testSameStudioCollapsesToOneRowKeepingTheBest() {
    let labels = AudioTracks.descriptions(for: spiderNoir, preferredLanguages: preferredENThenRU)
    let newStudio = labels.filter { $0.contains("NewStudio") }
    XCTAssertEqual(newStudio.count, 1)
    XCTAssertEqual(newStudio.first, expectedLabel(lang: "rus", typeId: 2, studio: "NewStudio"))
    XCTAssertFalse(labels.contains { $0.contains("aac") || $0.contains("ac3") || $0.contains("5.1") })
  }

  func testUniqueRowsKeepThePlainLabel() {
    let labels = AudioTracks.descriptions(for: spiderNoir, preferredLanguages: preferredENThenRU)
    let lostFilm = labels.first { $0.contains("LostFilm") }
    XCTAssertEqual(lostFilm, expectedLabel(lang: "rus", typeId: 2, studio: "LostFilm"))
  }

  // MARK: - Kind parsing

  func testTypeIdKindRanks() {
    XCTAssertEqual(AudioTracks.kindRank(typeId: 1, typeTitle: nil, typeShortTitle: nil), 0)
    XCTAssertEqual(AudioTracks.kindRank(typeId: 2, typeTitle: nil, typeShortTitle: nil), 1)
    XCTAssertEqual(AudioTracks.kindRank(typeId: 5, typeTitle: nil, typeShortTitle: nil), 4)
    XCTAssertEqual(AudioTracks.kindRank(typeId: 6, typeTitle: nil, typeShortTitle: nil), 5)
  }

  func testAVOIsRecognisedBeforeVOInLabels() {
    XCTAssertEqual(AudioTracks.kindRank(fromLabel: "Русский AVO (М. Яроцкий)"), 4)
    XCTAssertEqual(AudioTracks.kindRank(fromLabel: "Русский — Авторский"), 4)
    XCTAssertEqual(AudioTracks.kindRank(fromLabel: "Русский — Одноголосый"), 3)
  }

  func testAuthorIsReadFromTrailingParentheses() {
    XCTAssertEqual(AudioTracks.authorFromDisplayName("Russian · Multi (LostFilm)"), "LostFilm")
    XCTAssertNil(AudioTracks.authorFromDisplayName("English · Original"))
  }

  func testAuthorIsReadFromBulletSeparatedLabel() {
    XCTAssertEqual(AudioTracks.authorFromDisplayName("Russian ∙ Multi-voice, LostFilm"), "LostFilm")
    XCTAssertEqual(AudioTracks.authorFromDisplayName("Russian ∙ Multi-voice, NewStudio ∙ 2"), "NewStudio")
    XCTAssertEqual(AudioTracks.authorFromDisplayName("Russian ∙ multi-voice ∙ LostFilm"), "LostFilm")
    XCTAssertNil(AudioTracks.authorFromDisplayName("English ∙ Original"))
  }

  private func expectedLabel(lang: String, typeId: Int, studio: String?) -> String {
    AudioTracks.baseLabel(track(lang: lang, typeId: typeId, typeTitle: "", author: studio, index: 0))
  }
}
