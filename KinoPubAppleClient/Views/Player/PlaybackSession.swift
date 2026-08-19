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
    let created = PlayerManager(
      playItem: item,
      watchMode: mode,
      downloadedFilesDatabase: downloadedFilesDatabase,
      actionsService: actionsService
    )
    manager = created
    request = next
    return created
  }

  func clear() {
    manager?.tearDownForReplacement()
    manager = nil
    request = nil
  }
}
