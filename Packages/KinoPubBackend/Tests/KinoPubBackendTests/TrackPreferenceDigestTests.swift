//
//  TrackPreferenceDigestTests.swift
//
//  What Settings shows about remembered tracks, and in what order.
//

import XCTest
@testable import KinoPubBackend

final class TrackPreferenceDigestTests: XCTestCase {

  private func signature(_ lang: String, _ kindRank: Int, _ studio: String? = nil) -> AudioTrackSignature {
    AudioTrackSignature(languageKey: lang, kindRank: kindRank, studio: studio)
  }

  private func ledger(_ entries: [(AudioTrackSignature, Int)],
                      subtitles: [(SubtitleChoiceSignature, Int)] = []) -> TrackPreferenceLedger {
    var ledger = TrackPreferenceLedger()
    for (signature, weight) in entries {
      ledger.recordAudio(signature, at: Date(timeIntervalSince1970: 0), weight: weight)
    }
    for (signature, weight) in subtitles {
      ledger.recordSubtitle(signature, at: Date(timeIntervalSince1970: 0), weight: weight)
    }
    return ledger
  }

  // MARK: - Round-tripping a scope

  func testEveryScopeShapeSurvivesItsKey() {
    let scopes: [TrackMemoryScope] = [
      .episode(titleID: 42, season: 2, episode: 5),
      .episode(titleID: 42, season: nil, episode: 1),
      .season(titleID: 42, season: 3),
      .title(id: 42),
      .anime
    ]
    for scope in scopes {
      XCTAssertEqual(TrackMemoryScope(storageKey: scope.storageKey), scope, "\(scope)")
    }
  }

  func testAKeyFromAnotherBuildIsRefusedRatherThanGuessed() {
    XCTAssertNil(TrackMemoryScope(storageKey: ""))
    XCTAssertNil(TrackMemoryScope(storageKey: "t:"))
    XCTAssertNil(TrackMemoryScope(storageKey: "x:42"))
    XCTAssertNil(TrackMemoryScope(storageKey: "s:42"))
    XCTAssertNil(TrackMemoryScope(storageKey: "c:"))
  }

  // MARK: - Labels

  func testADubReadsAsLanguageKindStudio() {
    XCTAssertEqual(signature("ru", 0, "Мосфильм").displayLabel,
                   "\(LanguageNames.name(for: "ru")) ∙ \(AudioTracks.localizedKindLabel(rank: 0)!), Мосфильм")
  }

  func testAnAnonymousDubDropsTheComma() {
    let label = signature("ru", 1).displayLabel
    XCTAssertFalse(label.contains(","))
    XCTAssertTrue(label.contains(AudioTracks.localizedKindLabel(rank: 1)!))
  }

  func testAnUnknownKindFallsBackToTheLanguage() {
    XCTAssertEqual(signature("ru", AudioTracks.kindRankUnknown).displayLabel,
                   LanguageNames.name(for: "ru"))
  }

  func testSubtitlesOffSayThatTheyAreOff() {
    XCTAssertFalse(SubtitleChoiceSignature.off.displayLabel.isEmpty)
    XCTAssertEqual(SubtitleChoiceSignature(languageKey: "en", isCC: true).displayLabel,
                   "\(LanguageNames.name(for: "en")) (CC)")
  }

  // MARK: - Grouping

  func testTheStrongestEntryIsTheLeader() {
    let syenduk = signature("ru", 2, "Сыендук")
    let sections = TrackPreferenceDigest.sections(from: [
      .title(id: 42): ledger([(syenduk, 9), (signature("ru", 1, "LostFilm"), 2)])
    ])
    let audio = sections.first?.groups.first?.audio
    XCTAssertEqual(audio?.first?.label, syenduk.displayLabel)
    XCTAssertEqual(audio?.first?.weight, 9)
    XCTAssertEqual(audio?.first?.isLeader, true)
    XCTAssertEqual(audio?.last?.isLeader, false)
  }

  /// The reader thinks broadest-first, which is the reverse of the order the resolver asks.
  func testAScopeReadsBroadestFirst() {
    let dub = signature("ru", 0, "Мосфильм")
    let sections = TrackPreferenceDigest.sections(from: [
      .episode(titleID: 42, season: 1, episode: 3): ledger([(dub, 1)]),
      .title(id: 42): ledger([(dub, 5)]),
      .season(titleID: 42, season: 1): ledger([(dub, 3)])
    ])
    XCTAssertEqual(sections.first?.groups.map(\.scope),
                   [.title(id: 42),
                    .season(titleID: 42, season: 1),
                    .episode(titleID: 42, season: 1, episode: 3)])
  }

  func testTitlesReadHeaviestFirst() {
    let dub = signature("ru", 0, "Мосфильм")
    let sections = TrackPreferenceDigest.sections(from: [
      .title(id: 1): ledger([(dub, 2)]),
      .title(id: 2): ledger([(dub, 20)])
    ])
    XCTAssertEqual(sections.map(\.titleID), [2, 1])
  }

  /// A bucket is not about any one title, so it does not compete with them for the top.
  func testTheAnimeBucketReadsLast() {
    let dub = signature("ru", 0, "Мосфильм")
    let sections = TrackPreferenceDigest.sections(from: [
      .anime: ledger([(signature("ja", 5), 99)]),
      .title(id: 1): ledger([(dub, 2)])
    ])
    XCTAssertEqual(sections.map(\.titleID), [1, nil])
  }

  /// A row saying a series has no preference tells the reader nothing.
  func testAScopeThatLearnedNothingIsNotShown() {
    let sections = TrackPreferenceDigest.sections(from: [
      .title(id: 42): TrackPreferenceLedger(),
      .season(titleID: 42, season: 1): TrackPreferenceLedger()
    ])
    XCTAssertTrue(sections.isEmpty)
  }

  /// Seeing a menu is not learning a preference.
  func testASeenMenuAloneIsNotAPreference() {
    var seenOnly = TrackPreferenceLedger()
    seenOnly.seenAudio.insert(signature("ru", 0, "Мосфильм"))
    XCTAssertTrue(TrackPreferenceDigest.sections(from: [.title(id: 42): seenOnly]).isEmpty)
  }

  func testSubtitlesAreCarriedAlongsideAudio() {
    let sections = TrackPreferenceDigest.sections(from: [
      .title(id: 42): ledger([(signature("ru", 0), 3)],
                             subtitles: [(SubtitleChoiceSignature(languageKey: "en", isCC: false), 3)])
    ])
    XCTAssertEqual(sections.first?.groups.first?.subtitles.first?.label,
                   LanguageNames.name(for: "en"))
  }

  func testTheSectionWeightCountsEveryScope() {
    let dub = signature("ru", 0, "Мосфильм")
    let sections = TrackPreferenceDigest.sections(from: [
      .title(id: 42): ledger([(dub, 5)]),
      .season(titleID: 42, season: 1): ledger([(dub, 3)])
    ])
    XCTAssertEqual(sections.first?.weight, 8)
  }
}
