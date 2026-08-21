//
//  PlaybackSession.swift
//  KinoPubAppleClient
//
//  App-scoped playback coordinator: one AVPlayer/session for the whole app.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import KinoPubBackend
import KinoPubKit

/// Owns the single active `PlayerManager`. Navigation destinations and the macOS
/// player window host this session instead of constructing independent managers.
@MainActor
final class PlaybackSession: ObservableObject {
  static let shared = PlaybackSession()

  struct Request: Equatable {
    let itemID: Int
    let mode: WatchMode

    static func == (lhs: Request, rhs: Request) -> Bool {
      lhs.itemID == rhs.itemID && lhs.mode == rhs.mode
    }
  }

  @Published private(set) var request: Request?
  @Published private(set) var manager: PlayerManager?

  private init() {}

  /// Returns the shared manager for `item`, replacing the previous request when the
  /// id/mode changes so only one stream runs at a time.
  @discardableResult
  func play(
    item: any PlayableItem,
    mode: WatchMode,
    downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>,
    actionsService: UserActionsService
  ) -> PlayerManager {
    let next = Request(itemID: item.id, mode: mode)
    if let manager, request == next {
      return manager
    }

    manager?.tearDownForReplacement()
    if let media = item as? MediaItem {
      AppContext.shared.localProgressStore.cacheItem(media)
    }
    // The plan is made here rather than inside the player so the hand-off is the thing
    // that travels: whatever a card or a Play button already said about this title is what
    // the player starts from, and the player refines it once it sees the real renditions.
    let profile = Self.trackProfile(for: item)
    let created = PlayerManager(
      playItem: item,
      watchMode: mode,
      downloadedFilesDatabase: downloadedFilesDatabase,
      actionsService: actionsService,
      trackProfile: profile,
      plan: PlaybackPreflight.shared.plan(for: item, profile: profile)
    )
    manager = created
    request = next
    return created
  }

  /// Anime-ness and the original language, for track selection.
  ///
  /// Both come off the **item** payload, which an `Episode` is not: it carries no genres
  /// and no countries. The series snapshot the user browsed to get here does, so that is
  /// what is read — and when there is none, the resolver simply falls back to the ladder.
  private static func trackProfile(for item: any PlayableItem) -> TitleTrackProfile {
    let snapshot = (item as? MediaItem)
      ?? AppContext.shared.localProgressStore.snapshot(for: item.metadata.id)
    guard let snapshot else { return TitleTrackProfile() }
    let languages = item.audioTracks.map(\.lang) + item.subtitles.map(\.lang)
    let presentation = MediaPresentationProfile(type: snapshot.type, genres: snapshot.genres)
    return TitleTrackProfile.infer(presentation: presentation,
                                   countries: snapshot.countries.map(\.title),
                                   trackLanguages: languages)
  }

  func clear() {
    manager?.tearDownForReplacement()
    manager = nil
    request = nil
  }
}
