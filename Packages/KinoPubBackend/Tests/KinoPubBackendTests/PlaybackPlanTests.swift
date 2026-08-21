//
//  PlaybackPlanTests.swift
//
//  What a surface can say when it is holding a plan.
//

import XCTest
@testable import KinoPubBackend

final class PlaybackPlanTests: XCTestCase {

  private func audio(_ lang: String, _ typeId: Int, _ studio: String? = nil) -> AudioTrackInfo {
    let titles = [1: "Дубляж", 2: "Многоголосый", 3: "Двухголосый", 6: "Оригинал"]
    return AudioTrackInfo(lang: lang, typeId: typeId, typeTitle: titles[typeId], authorTitle: studio)
  }

  private func plan(_ decision: TrackDecision, provisional: Bool = true) -> PlaybackPlan {
    PlaybackPlan(itemID: 1, scopes: [.title(id: 42)], decision: decision, isProvisional: provisional)
  }

  func testNothingKnownSaysNothing() {
    let unknown = PlaybackPlan.unknown(itemID: 7)
    XCTAssertNil(unknown.audioLabel)
    XCTAssertNil(unknown.subtitleLabel)
    XCTAssertFalse(unknown.hadAChoice)
    XCTAssertFalse(unknown.isRemembered)
    XCTAssertTrue(unknown.scopes.isEmpty)
  }

  func testTheDubIsNamedWhenThereWasAChoice() {
    let lostfilm = audio("ru", 2, "LostFilm")
    let named = plan(TrackDecision(audio: lostfilm, audioReason: .ladder))
    XCTAssertEqual(named.audioLabel, AudioTracks.baseLabel(lostfilm))
    XCTAssertTrue(named.hadAChoice)
  }

  /// Naming the only track there was tells the viewer nothing they can act on.
  func testTheOnlyOptionIsNotNamed() {
    let single = plan(TrackDecision(audio: audio("ru", 1, "Мосфильм"), audioReason: .onlyOption))
    XCTAssertNil(single.audioLabel)
    XCTAssertFalse(single.hadAChoice)
  }

  /// The difference a diagnostics screen groups by: what the viewer watches, versus what
  /// we picked for them.
  func testRememberedIsToldApartFromPicked() {
    XCTAssertTrue(plan(TrackDecision(audioReason: .remembered)).isRemembered)
    XCTAssertTrue(plan(TrackDecision(audioReason: .rememberedAlternate)).isRemembered)
    XCTAssertFalse(plan(TrackDecision(audioReason: .ladder)).isRemembered)
    XCTAssertFalse(plan(TrackDecision(audioReason: .newBetterDub)).isRemembered)
    XCTAssertFalse(plan(TrackDecision(audioReason: .originalPreferred)).isRemembered)
  }

  func testSubtitlesOffHaveNoLabel() {
    XCTAssertNil(plan(TrackDecision(subtitleReason: .off)).subtitleLabel)
  }

  func testASubtitleTrackIsNamed() {
    let tracks = SubtitleTracks.catalog([Subtitle(lang: "en", shift: 0, embed: false, url: "https://cdn/en.srt")])
    let withSubs = plan(TrackDecision(subtitle: tracks.first, subtitleReason: .systemDefault))
    XCTAssertEqual(withSubs.subtitleLabel, tracks.first?.displayName)
  }

  /// A plan made from API metadata is a snapshot; the player replaces it once it can see
  /// the real renditions.
  func testProvisionalIsTheDefaultAndIsCarried() {
    XCTAssertTrue(plan(TrackDecision()).isProvisional)
    XCTAssertFalse(plan(TrackDecision(), provisional: false).isProvisional)
  }
}
