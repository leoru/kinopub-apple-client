//
//  PlaybackPlan.swift
//
//

import Foundation

/// **What is known about how a title will play, before it plays.**
///
/// A value that surfaces hand to each other rather than each deriving its own: the card
/// that was tapped, the detail hero's Play button, the player, a diagnostics row. Two
/// derivations of the same question are two answers, and the one the viewer sees on a
/// button has to be the one that actually starts.
///
/// It is a **snapshot, not a promise**. The menu it was made from is whatever that surface
/// could see; the player sees more — the real HLS renditions — and refreshes the plan when
/// it does. `isProvisional` says which of those you are holding.
///
/// Rules behind the decision: [docs/product/playback-tracks.md].
public struct PlaybackPlan: Equatable {

  public let itemID: Int
  /// The scopes this decision was read from, most specific first. Empty for an item with
  /// no resolved id — nothing is remembered for one of those.
  public let scopes: [TrackMemoryScope]
  public let decision: TrackDecision
  /// True while this was decided from API metadata alone. The player replaces it once the
  /// asset publishes its real renditions.
  public let isProvisional: Bool

  public init(itemID: Int,
              scopes: [TrackMemoryScope],
              decision: TrackDecision,
              isProvisional: Bool = true) {
    self.itemID = itemID
    self.scopes = scopes
    self.decision = decision
    self.isProvisional = isProvisional
  }

  /// Nothing is known yet — no tracks, or an item nobody has looked at.
  public static func unknown(itemID: Int) -> PlaybackPlan {
    PlaybackPlan(itemID: itemID, scopes: [], decision: TrackDecision())
  }

  // MARK: - What a surface can say

  public var audio: AudioTrackInfo? { decision.audio }
  public var subtitle: SubtitleTrack? { decision.subtitle }

  /// The dub, named — "Русский ∙ Дубляж, LostFilm". `nil` when there was no choice to
  /// make, because naming the only option tells the viewer nothing they can act on.
  public var audioLabel: String? {
    guard hadAChoice, let audio = decision.audio else { return nil }
    return AudioTracks.baseLabel(audio)
  }

  /// The subtitle track, named, or `nil` when subtitles are off.
  public var subtitleLabel: String? {
    decision.subtitle?.displayName
  }

  /// Whether this plan is worth showing at all: a title with one dub and no subtitles has
  /// nothing to say about tracks.
  public var hadAChoice: Bool {
    decision.audioReason != .onlyOption && decision.audioReason != .none
  }

  /// Whether the viewer's own history decided this, rather than the ladder. What a
  /// diagnostics screen groups by, and the difference between "this is what you watch" and
  /// "this is what we picked".
  public var isRemembered: Bool {
    decision.audioReason == .remembered || decision.audioReason == .rememberedAlternate
  }
}
