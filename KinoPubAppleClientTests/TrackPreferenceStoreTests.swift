//
//  TrackPreferenceStoreTests.swift
//  KinoPubAppleClientTests
//
//  The store's own job: which scopes a play teaches, what survives a relaunch, and the
//  one-way migration off the old keys. The *rules* it feeds are covered in
//  KinoPubBackendTests — this is about persistence.
//

import XCTest
import KinoPubBackend
// The app target's module is `KinoPub` — `PRODUCT_NAME` is KinoPub and nothing overrides
// `PRODUCT_MODULE_NAME`, so it is not the target name.
@testable import KinoPub

final class TrackPreferenceStoreTests: XCTestCase {

  private var defaults: UserDefaults!
  private var suiteName: String!

  override func setUpWithError() throws {
    suiteName = "TrackPreferenceStoreTests.\(UUID().uuidString)"
    defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
  }

  override func tearDownWithError() throws {
    defaults.removePersistentDomain(forName: suiteName)
  }

  private let seriesID = 4242

  private func syenduk() -> AudioTrackSignature {
    AudioTrackSignature(languageKey: "ru", kindRank: 2, studio: "Сыендук")
  }

  private func chain(isAnime: Bool = false) -> [TrackMemoryScope] {
    TrackMemoryScope.chain(titleID: seriesID, season: 2, episode: 5, isAnime: isAnime)
  }

  // MARK: - Writing

  /// A play teaches every scope it belongs to, not only the most specific one — that is
  /// what lets the next season start from the series' own preference.
  func testAPlayTeachesEveryScopeInTheChain() {
    let store = TrackPreferenceStore(defaults: defaults)
    store.recordAudio(syenduk(), in: chain())

    XCTAssertEqual(store.ledger(for: .episode(titleID: seriesID, season: 2, episode: 5))?.audio.first?.weight, 1)
    XCTAssertEqual(store.ledger(for: .season(titleID: seriesID, season: 2))?.audio.first?.weight, 1)
    XCTAssertEqual(store.ledger(for: .title(id: seriesID))?.audio.first?.weight, 1)
    XCTAssertNil(store.ledger(for: .anime), "not an anime, so the bucket learns nothing")
  }

  func testAnAnimeAlsoTeachesTheAnimeBucket() {
    let store = TrackPreferenceStore(defaults: defaults)
    store.recordAudio(syenduk(), in: chain(isAnime: true))
    XCTAssertEqual(store.ledger(for: .anime)?.audio.first?.signature, syenduk())
  }

  func testWeightAccumulatesAcrossEpisodesOfOneSeries() {
    let store = TrackPreferenceStore(defaults: defaults)
    for episode in 1...4 {
      let scopes = TrackMemoryScope.chain(titleID: seriesID, season: 1, episode: episode)
      store.recordAudio(syenduk(), in: scopes)
    }

    XCTAssertEqual(store.ledger(for: .title(id: seriesID))?.audio.first?.weight, 4)
    XCTAssertEqual(store.ledger(for: .episode(titleID: seriesID, season: 1, episode: 1))?.audio.first?.weight,
                   1,
                   "each episode saw one play")
  }

  func testAnEmptyChainWritesNothing() {
    let store = TrackPreferenceStore(defaults: defaults)
    store.recordAudio(syenduk(), in: [])
    XCTAssertTrue(store.all.isEmpty)
  }

  func testTheMenuIsRecordedEvenWhenNothingIsChosen() {
    let store = TrackPreferenceStore(defaults: defaults)
    let dub = AudioTrackInfo(lang: "ru", typeId: 1, typeTitle: "Дубляж", authorTitle: "Мосфильм")
    store.noteMenu([dub], in: chain())

    let ledger = store.ledger(for: .title(id: seriesID))
    XCTAssertTrue(ledger?.seenAudio.contains(dub.signature) ?? false)
    XCTAssertTrue(ledger?.audio.isEmpty ?? false, "seeing is not choosing")
  }

  // MARK: - Reading

  /// The resolver walks a uniform shape, so a scope that learned nothing still appears.
  func testEveryScopeInTheChainIsReturnedEvenWhenEmpty() {
    let store = TrackPreferenceStore(defaults: defaults)
    let scoped = store.ledgers(for: chain(isAnime: true))

    XCTAssertEqual(scoped.count, 4)
    XCTAssertEqual(scoped.map(\.scope), chain(isAnime: true))
    XCTAssertTrue(scoped.allSatisfy(\.ledger.isEmpty))
  }

  func testLedgersSurviveANewStoreOverTheSameDefaults() {
    TrackPreferenceStore(defaults: defaults).recordAudio(syenduk(), in: chain())
    let reopened = TrackPreferenceStore(defaults: defaults)
    XCTAssertEqual(reopened.ledger(for: .title(id: seriesID))?.audio.first?.signature, syenduk())
  }

  func testForgettingOneScopeLeavesTheOthers() {
    let store = TrackPreferenceStore(defaults: defaults)
    store.recordAudio(syenduk(), in: chain())
    store.forget(scope: .season(titleID: seriesID, season: 2))

    XCTAssertNil(store.ledger(for: .season(titleID: seriesID, season: 2)))
    XCTAssertNotNil(store.ledger(for: .title(id: seriesID)))
  }

  // MARK: - Migration off the old keys

  /// `SubtitleTrackReference` carries a real language code, so it converts.
  func testLegacySubtitleChoicesAreMigratedOnce() throws {
    let choice = SubtitleChoice(primary: SubtitleTrackReference(lang: "en", isCC: false, ordinal: 0),
                                secondary: nil)
    defaults.set(try JSONEncoder().encode([String(seriesID): choice]), forKey: "subtitleTrackChoices")

    let store = TrackPreferenceStore(defaults: defaults)
    let migrated = store.ledger(for: .title(id: seriesID))?.subtitles.first?.signature

    XCTAssertEqual(migrated, SubtitleChoiceSignature(languageKey: "en", isCC: false))
    XCTAssertNil(defaults.data(forKey: "subtitleTrackChoices"), "the old key is consumed")
  }

  /// Subtitles deliberately off is a choice, and has to survive the move.
  func testLegacySubtitlesOffMigratesAsOff() throws {
    let choice = SubtitleChoice(primary: nil, secondary: nil)
    defaults.set(try JSONEncoder().encode([String(seriesID): choice]), forKey: "subtitleTrackChoices")

    let store = TrackPreferenceStore(defaults: defaults)
    XCTAssertEqual(store.ledger(for: .title(id: seriesID))?.subtitles.first?.signature, .off)
  }

  func testMigrationDoesNotOverwriteALedgerThatAlreadyExists() throws {
    TrackPreferenceStore(defaults: defaults).recordAudio(syenduk(), in: [.title(id: seriesID)])

    let choice = SubtitleChoice(primary: SubtitleTrackReference(lang: "en", isCC: false, ordinal: 0),
                                secondary: nil)
    defaults.set(try JSONEncoder().encode([String(seriesID): choice]), forKey: "subtitleTrackChoices")

    let store = TrackPreferenceStore(defaults: defaults)
    XCTAssertEqual(store.ledger(for: .title(id: seriesID))?.audio.first?.signature, syenduk())
  }
}
