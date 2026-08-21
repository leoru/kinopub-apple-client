//
//  PlaybackPreflight.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

/// **What a surface can know about playback before the player exists.**
///
/// Two jobs, and they are the same subject seen from either side of a tap:
///
/// - *Which dub and subtitles will this open with.* `TrackResolver` is pure and takes a
///   menu, so the answer does not need a player — a card, a Play button or a diagnostics
///   screen can ask for it while drawing. The player asks the same way, so nothing can
///   disagree with what actually plays.
/// - *Have the links ready before they are needed.* A series episode arrives without them
///   and the player fetches `/v1/items/media-links` on open, which is dead time the viewer
///   spends looking at a spinner. Warming it while the detail page is on screen moves that
///   request out of the tap.
///
/// Warming is safe to call repeatedly: `MediaLinksResolver` runs one request per media id
/// however many callers ask, and `Episode` is a class, so a filled one is filled for
/// everybody already holding it.
///
/// **Not `@MainActor` as a whole**, on purpose: asking what a title will play has to work
/// from `PlayerManager`, which is not main-actor-isolated and asks synchronously — from its
/// periodic time observer among other places. Only `warm` is isolated, because the resolver
/// it drives is. The cache is behind a lock rather than an actor for the same reason.
final class PlaybackPreflight {

  static let shared = PlaybackPreflight()

  private let preferences: TrackPreferenceStore
  private let contentServiceOverride: VideoContentService?

  /// The content service is resolved when it is first needed rather than held, so asking
  /// what a title would play never builds the app context. That matters for a test, which
  /// wants the decision without a network stack behind it.
  private var contentService: VideoContentService {
    contentServiceOverride ?? AppContext.shared.contentService
  }

  init(preferences: TrackPreferenceStore = AppContext.shared.trackPreferences,
       contentService: VideoContentService? = nil) {
    self.preferences = preferences
    self.contentServiceOverride = contentService
  }

  /// One plan per item, kept so a card, a button and the player hand each other the same
  /// answer instead of each deriving one. Rebuilt when the history changes or the menu it
  /// was decided from does.
  private struct CachedPlan {
    let plan: PlaybackPlan
    let revision: Int
    let audioFingerprint: Int
    let subtitleFingerprint: Int
  }

  private var cache: [Int: CachedPlan] = [:]
  private let cacheLock = NSLock()

  private func cachedPlan(for id: Int) -> CachedPlan? {
    cacheLock.lock(); defer { cacheLock.unlock() }
    return cache[id]
  }

  private func store(_ cached: CachedPlan, for id: Int) {
    cacheLock.lock(); defer { cacheLock.unlock() }
    cache[id] = cached
  }

  // MARK: - Knowing

  /// The scopes this item's history lives under. `WatchingMetadata.id` is the **series**
  /// for an episode, so the title scope is the series either way.
  ///
  /// Empty for an unresolved item: a preference stored under id 0 would pool every such
  /// title into one bucket.
  func scopes(for item: any PlayableItem, profile: TitleTrackProfile) -> [TrackMemoryScope] {
    guard item.metadata.isResolved else { return [] }
    return TrackMemoryScope.chain(titleID: item.metadata.id,
                                  season: item.metadata.season,
                                  episode: item.metadata.video,
                                  isAnime: profile.isAnime)
  }

  /// Which tracks this would open with, from what is already loaded. No network, so it is
  /// safe to call while drawing.
  ///
  /// The player passes its own `audioMenu` because it can see the real renditions — which
  /// is the better menu when the API gave no track metadata. Everyone else gets the API's.
  func decision(for item: any PlayableItem,
                profile: TitleTrackProfile,
                audioMenu: [AudioTrackInfo]? = nil,
                subtitles: [SubtitleTrack]? = nil) -> TrackDecision {
    plan(for: item, profile: profile, audioMenu: audioMenu, subtitles: subtitles).decision
  }

  /// **The object surfaces pass around.** Everything known about how this item will play,
  /// ready to hand from the card that was tapped to the page to the player.
  ///
  /// Cached per item and rebuilt only when the history or the menu changes, so asking on
  /// every render is free and every asker gets the identical answer.
  ///
  /// `audioMenu` is the player's to pass: it can see the real renditions, which beat the
  /// API's list when there is none. A plan made without it is `isProvisional`.
  func plan(for item: any PlayableItem,
            profile: TitleTrackProfile,
            audioMenu: [AudioTrackInfo]? = nil,
            subtitles: [SubtitleTrack]? = nil) -> PlaybackPlan {
    let audio = audioMenu ?? item.audioTracks
    let subs = subtitles ?? SubtitleTracks.catalog(item.subtitles)
    let audioFingerprint = audio.hashValue
    let subtitleFingerprint = subs.hashValue

    if let cached = cachedPlan(for: item.id),
       cached.revision == preferences.revision,
       cached.audioFingerprint == audioFingerprint,
       cached.subtitleFingerprint == subtitleFingerprint,
       cached.plan.isProvisional == (audioMenu == nil) {
      return cached.plan
    }

    let scopes = scopes(for: item, profile: profile)
    let plan = PlaybackPlan(itemID: item.id,
                            scopes: scopes,
                            decision: TrackResolver.resolve(audio: audio,
                                                            subtitles: subs,
                                                            ledgers: preferences.ledgers(for: scopes),
                                                            settings: PlaybackLanguagePreferences.current,
                                                            profile: profile),
                            isProvisional: audioMenu == nil)
    store(CachedPlan(plan: plan,
                     revision: preferences.revision,
                     audioFingerprint: audioFingerprint,
                     subtitleFingerprint: subtitleFingerprint),
          for: item.id)
    return plan
  }

  /// The dub this would play, as a label — "Русский ∙ Дубляж, LostFilm".
  func audioSummary(for item: any PlayableItem, profile: TitleTrackProfile) -> String? {
    plan(for: item, profile: profile).audioLabel
  }

  // MARK: - Warming

  /// Fetch what playing this item will need, before it is asked for.
  ///
  /// A no-op for anything that already has a playable link, so calling it on every render
  /// costs nothing. Failures are deliberately silent — this is an optimisation, and the
  /// player still does its own resolve and still owns reporting a stream it cannot play.
  @MainActor
  func warm(_ item: any PlayableItem) async {
    guard let episode = item as? Episode else { return }
    guard !episode.files.hasPlayableURLs else { return }
    let filled = await MediaLinksResolver.shared.fill(episode, using: contentService)
    Logger.app.debug("preflight warmed episode \(episode.id) playable=\(filled)")
  }
}
