//
//  PlayerTrackSelectionTests.swift
//  KinoPubAppleClientTests
//
//  That the player asks the resolver — and gets the same answer — on every platform this
//  bundle runs on. The gap this covers was not a wrong rule but a missing one: the
//  cataloguing and the decision were fenced to tvOS, so on iOS nothing chose anything and
//  no test noticed, because there was no player test at all.
//
//  The bridge to what the system player can actually select (`SubtitleRenditions`) is
//  covered here too rather than only in `KinoPubBackend`: package tests run on macOS alone,
//  and this bundle runs on the iOS and tvOS simulators in CI.
//

import XCTest
import AVFoundation
import KinoPubBackend
import KinoPubKit
// The app target's module is `KinoPub` — see `PlaybackPreflightTests`.
@testable import KinoPub

@MainActor
final class PlayerTrackSelectionTests: XCTestCase {

  private struct StubItem: PlayableItem {
    let id: Int
    var files: [FileInfo] = []
    var trailer: Trailer?
    var metadata: WatchingMetadata
    var subtitles: [Subtitle] = []
    var audioTracks: [AudioTrackInfo] = []
  }

  private var defaults: UserDefaults!
  private var suiteName: String!
  private var store: TrackPreferenceStore!
  private var preflight: PlaybackPreflight!

  override func setUpWithError() throws {
    suiteName = "PlayerTrackSelectionTests.\(UUID().uuidString)"
    defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    store = TrackPreferenceStore(defaults: defaults)
    preflight = PlaybackPreflight(preferences: store, contentService: VideoContentServiceMock())
  }

  override func tearDownWithError() throws {
    defaults.removePersistentDomain(forName: suiteName)
  }

  private func subtitles(_ languages: [String]) -> [Subtitle] {
    languages.map { Subtitle(lang: $0, shift: 0, embed: false, url: "https://e.x/\($0).srt") }
  }

  private func manager(for item: StubItem, mode: WatchMode = .media) -> PlayerManager {
    PlayerManager(playItem: item,
                  watchMode: mode,
                  downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver()),
                  actionsService: UserActionsServiceMock(),
                  contentService: VideoContentServiceMock(),
                  trackPreferences: store,
                  preflight: preflight)
  }

  private func item(subtitles languages: [String],
                    audio: [AudioTrackInfo] = []) -> StubItem {
    StubItem(id: 7,
             metadata: WatchingMetadata(id: 7, video: 1, season: nil),
             subtitles: subtitles(languages),
             audioTracks: audio)
  }

  // MARK: - The player asks, on every platform

  /// The catalogue existing at all is the platform-fenced half that was missing: off tvOS
  /// `subtitleTracks` stayed empty, so there was nothing for anything to decide between.
  func testTheItemsSubtitlesAreCataloguedWhereverThePlayerRuns() {
    let player = manager(for: item(subtitles: ["rus", "eng"]))
    XCTAssertEqual(player.subtitleTracks.count, 2)
    XCTAssertEqual(player.subtitleTracks.map(\.lang), ["rus", "eng"])
  }

  /// The player must not answer this question its own way. Whatever a card or a Play button
  /// would have been told is what the player opens with.
  func testTheOpeningSubtitleIsWhateverThePreflightDecided() {
    let stub = item(subtitles: ["rus", "eng"])
    let expected = preflight.plan(for: stub,
                                  profile: TitleTrackProfile(),
                                  subtitles: SubtitleSelector.tracks(in: stub.subtitles))
    XCTAssertEqual(manager(for: stub).primaryTrack, expected.decision.subtitle)
  }

  /// A remembered choice is the strongest input there is, and it has to reach the player on
  /// the platform the choice was made on *and* the ones it was not.
  func testARememberedChoiceIsWhatThePlayerOpensWith() throws {
    let stub = item(subtitles: ["rus", "eng"])
    let english = try XCTUnwrap(SubtitleSelector.tracks(in: stub.subtitles).last)
    store.recordSubtitle(SubtitleChoiceSignature(english),
                         in: preflight.scopes(for: stub, profile: TitleTrackProfile()))
    XCTAssertEqual(manager(for: stub).primaryTrack?.lang, "eng")
  }

  /// "Off" is a choice like any other — the next episode has to honour it.
  func testARememberedOffOpensWithoutSubtitles() {
    let stub = item(subtitles: ["rus", "eng"])
    store.recordSubtitle(.off, in: preflight.scopes(for: stub, profile: TitleTrackProfile()))
    XCTAssertNil(manager(for: stub).primaryTrack)
  }

  func testATrailerChoosesNothingAndTeachesNothing() {
    let player = manager(for: item(subtitles: ["rus"]), mode: .trailer)
    XCTAssertTrue(player.subtitleTracks.isEmpty)
    XCTAssertNil(player.primaryTrack)
  }

  // MARK: - The bridge to what the system player can select

  /// Same assertions as the package's own, run here because these are the platforms the
  /// selection actually happens on.
  func testTheDecidedTrackFindsItsRenditionOnThisPlatform() throws {
    let catalog = SubtitleSelector.tracks(in: subtitles(["rus", "eng", "ai"]))
    let renditions = [StubRendition(renditionLanguageCode: "ru"),
                      StubRendition(renditionLanguageCode: "en"),
                      StubRendition(renditionLanguageCode: "ai")]
    for (index, track) in catalog.enumerated() {
      XCTAssertEqual(SubtitleRenditions.renditionIndex(for: track, among: catalog, in: renditions),
                     index,
                     "\(track.lang) did not find its rendition")
    }
  }

  func testMachineTranslatedRussianIsItsOwnLanguageOnThisPlatform() {
    XCTAssertNotEqual(SubtitleTracks.languageKey("ai"), SubtitleTracks.languageKey("rus"))
    XCTAssertEqual(SubtitleTracks.languageKey("uzb"), "uz")
    XCTAssertEqual(SubtitleTracks.languageKey("phi"), "fil")
  }

  /// Every language id kino.pub's own reference list ships, resolved through one table.
  /// A code that normalises to nothing matches nothing, and the viewer silently loses that
  /// language — which is what `uzb` and `phi` did.
  func testEveryKinoPubSubtitleLanguageResolvesToSomething() {
    let ids = ["rus", "eng", "ukr", "fre", "ger", "spa", "ita", "por", "fin", "pol", "chi",
               "jpn", "kor", "hin", "heb", "swe", "nor", "dan", "ron", "kaz", "uzb", "phi",
               "tur", "ai"]
    var keys: Set<String> = []
    for id in ids {
      let key = SubtitleTracks.languageKey(id)
      XCTAssertFalse(key.isEmpty, "\(id) normalised to nothing")
      XCTAssertTrue(keys.insert(key).inserted, "\(id) collided with another language on \(key)")
      XCTAssertFalse(LanguageNames.name(for: id).isEmpty, "\(id) has no name to show")
    }
  }

  // MARK: - What the system player is told

  /// The panel cannot be asserted without a device, but the fact that an episode now
  /// carries its series' description, genres and year into it can — and that this happens
  /// on the platforms whose panel we are talking about.
  func testAnEpisodeCarriesItsSeriesIntoTheInfoPanel() {
    let series = MediaItem.mock()
    let items = PlaybackMetadata.items(title: "Series",
                                       subtitle: "Season 1, Episode 2",
                                       context: series)
    XCTAssertEqual(items.first { $0.identifier == .commonIdentifierTitle }?.stringValue, "Series")
    XCTAssertEqual(items.first { $0.identifier == .commonIdentifierDescription }?.stringValue,
                   series.plot)
    XCTAssertNotNil(items.first { $0.identifier == .commonIdentifierCreationDate })
  }

  private struct StubRendition: SubtitleRendition, Equatable {
    var renditionLanguageCode: String
    var isForcedRendition: Bool = false
    var isCaptioningRendition: Bool = false
  }
}
