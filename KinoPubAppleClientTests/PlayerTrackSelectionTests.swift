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

/// The master-playlist rewrite — what the system pickers (Audio / Subtitles) actually
/// list. Lives in this file because the test target's membership is spelled out file
/// by file in the project, and these cases belong to the same "what the player is
/// told" story as the selection tests above.
final class HLSAudioLabelerTests: XCTestCase {

  private let base = URL(string: "https://cdn.example.com/hls/master.m3u8")!

  /// Item 126352's shape: four real tracks repeated under three per-quality groups.
  private func master(audioGroups: [String] = ["audio1080", "audio720", "audio480"],
                      names: [(name: String, lang: String)] = [("01. Многоголосый. Rezka (RUS)", "rus"),
                                                               ("02. Многоголосый. Rezka 18+ (RUS)", "rus"),
                                                               ("03. Двухголосый. AlphaProject (RUS)", "rus"),
                                                               ("04. Оригинал (ENG)", "eng")]) -> String {
    var lines = ["#EXTM3U", "#EXT-X-VERSION:4"]
    lines.append("#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"sub\",NAME=\"RUS #01\",LANGUAGE=\"rus\",URI=\"sub/rus.m3u8\"")
    for (groupIndex, group) in audioGroups.enumerated() {
      for (nameIndex, rendition) in names.enumerated() {
        lines.append("#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"\(group)\",NAME=\"\(rendition.name)\",LANGUAGE=\"\(rendition.lang)\",DEFAULT=\(nameIndex == 0 ? "YES" : "NO"),AUTOSELECT=YES,URI=\"a\(nameIndex)-\(groupIndex)/index.m3u8\"")
      }
    }
    for group in audioGroups {
      lines.append("#EXT-X-STREAM-INF:BANDWIDTH=1000,AUDIO=\"\(group)\",SUBTITLES=\"sub\"")
      lines.append("vod/\(group).m3u8")
    }
    return lines.joined(separator: "\n")
  }

  /// The API's type ids, as item 126352 carries them — 6 is "Оригинал", not an index
  /// into the three named ones (an offset subscript there crashed the whole suite).
  private static let typeTitles = [1: "VO", 2: "Многоголосый", 3: "Двухголосый", 6: "Оригинал"]

  private func track(lang: String, typeId: Int, author: String? = nil, index: Int) -> AudioTrackInfo {
    AudioTrackInfo(lang: lang,
                   typeId: typeId,
                   typeTitle: Self.typeTitles[typeId],
                   typeShortTitle: nil,
                   authorTitle: author,
                   channels: 2,
                   codec: "aac",
                   index: index,
                   isAudioDescription: false)
  }

  private var apiTracks: [AudioTrackInfo] {
    [track(lang: "rus", typeId: 2, author: "Rezka", index: 1),
     track(lang: "rus", typeId: 2, author: "Rezka 18+", index: 2),
     track(lang: "rus", typeId: 3, author: "AlphaProject", index: 3),
     track(lang: "eng", typeId: 6, index: 4)]
  }

  private func audioLines(in playlist: String) -> [String] {
    playlist.split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)
      .filter { $0.contains("#EXT-X-MEDIA:") && $0.contains("TYPE=AUDIO") }
  }

  private func attribute(_ key: String, in line: String) -> String? {
    guard let range = line.range(of: "\(key)=\"[^\"]*\"", options: .regularExpression) else { return nil }
    return String(line[range]).split(separator: "\"").dropFirst().first.map(String.init)
  }

  // MARK: - The per-quality collapse

  /// The bug behind "восемь русских озвучек": every track listed once per video
  /// quality, all rows identical. Four real tracks stay four rows.
  func testPerQualityCopiesCollapseIntoOneAudioGroup() {
    let rewritten = HLSAudioLabeler.rewrite(master(), baseURL: base, tracks: apiTracks)
    let audio = audioLines(in: rewritten)
    XCTAssertEqual(audio.count, 4)
    XCTAssertEqual(Set(audio.map { attribute("GROUP-ID", in: $0) }), ["audio1080"])

    let streamAudioGroups = rewritten.split(separator: "\n")
      .filter { $0.hasPrefix("#EXT-X-STREAM-INF:") }
      .map { attribute("AUDIO", in: String($0)) }
    XCTAssertEqual(streamAudioGroups, ["audio1080", "audio1080", "audio1080"])

    XCTAssertTrue(rewritten.contains("GROUP-ID=\"sub\""), "the subtitle group is not ours to touch")
  }

  /// "01. …" in the CDN name is the API index — Rezka 18+ has to land on row 2 even
  /// when the API lists its tracks in another order.
  func testLabelsMatchTracksByTheLeadingNumber() {
    let rewritten = HLSAudioLabeler.rewrite(master(), baseURL: base, tracks: apiTracks.reversed())
    let names = audioLines(in: rewritten).map { attribute("NAME", in: $0) }
    XCTAssertEqual(names, [AudioTracks.baseLabel(track(lang: "rus", typeId: 2, author: "Rezka", index: 1)),
                           AudioTracks.baseLabel(track(lang: "rus", typeId: 2, author: "Rezka 18+", index: 2)),
                           AudioTracks.baseLabel(track(lang: "rus", typeId: 3, author: "AlphaProject", index: 3)),
                           AudioTracks.baseLabel(track(lang: "eng", typeId: 6, index: 4))])
  }

  /// Masters without numbered names still match by language, in master order.
  func testLanguageOrderIsTheFallbackWhenNamesHaveNoNumber() {
    let flat = master(audioGroups: ["audio"],
                      names: [("Russian", "rus"), ("Russian", "rus"), ("English", "eng")])
    let tracks = [track(lang: "rus", typeId: 1, author: "Red Head Sound", index: 1),
                  track(lang: "rus", typeId: 2, author: "LostFilm", index: 2),
                  track(lang: "eng", typeId: 6, index: 3)]
    let names = audioLines(in: HLSAudioLabeler.rewrite(flat, baseURL: base, tracks: tracks))
      .map { attribute("NAME", in: $0) }
    XCTAssertEqual(names, [AudioTracks.baseLabel(tracks[0]),
                           AudioTracks.baseLabel(tracks[1]),
                           AudioTracks.baseLabel(tracks[2])])
  }

  /// A rendition the API doesn't know keeps its CDN name — it says more than "Russian".
  func testUnmatchedSurvivorKeepsItsCDNName() {
    let rewritten = HLSAudioLabeler.rewrite(master(), baseURL: base,
                                            tracks: apiTracks.filter { $0.index != 3 })
    let names = audioLines(in: rewritten).map { attribute("NAME", in: $0) }
    XCTAssertEqual(names[2], "03. Двухголосый. AlphaProject (RUS)")
  }

  func testDuplicateLabelsAreUniqued() {
    let flat = master(audioGroups: ["audio"],
                      names: [("Russian", "rus"), ("Russian", "rus")])
    let colliding = [track(lang: "rus", typeId: 2, author: "NewStudio", index: 1),
                     track(lang: "rus", typeId: 2, author: "NewStudio", index: 2)]
    let names = audioLines(in: HLSAudioLabeler.rewrite(flat, baseURL: base, tracks: colliding))
      .map { attribute("NAME", in: $0) }
    XCTAssertEqual(names[0], AudioTracks.baseLabel(colliding[0]))
    XCTAssertEqual(names[1], "\(AudioTracks.baseLabel(colliding[0])) ∙ 2")
  }

  // MARK: - DEFAULT

  /// The signed default comes from the sort ladder: with English preferred, the
  /// original is the one AVFoundation opens with.
  func testDefaultMovesToTheBestTrack() {
    let rewritten = HLSAudioLabeler.rewrite(master(), baseURL: base, tracks: apiTracks,
                                            preferredLanguages: ["en-US"])
    let audio = audioLines(in: rewritten)
    XCTAssertEqual(audio.map { $0.contains("DEFAULT=YES") }, [false, false, false, true])
  }

  /// With no API tracks the collapse still happens, and the CDN's own DEFAULT pick
  /// survives untouched.
  func testWithoutAPITracksTheCDNDefaultSurvives() {
    let rewritten = HLSAudioLabeler.rewrite(master(), baseURL: base, tracks: [])
    let audio = audioLines(in: rewritten)
    XCTAssertEqual(audio.count, 4)
    XCTAssertEqual(audio.map { $0.contains("DEFAULT=YES") }, [true, false, false, false])
    XCTAssertEqual(audio.map { attribute("NAME", in: $0) }[0], "01. Многоголосый. Rezka (RUS)")
  }
}
