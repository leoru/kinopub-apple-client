//
//  MediaCardMenuCoordinator.swift
//  KinoPubAppleClient
//
//  Shared side effects for card context menus: play, watchlist, bookmark folders,
// mark watched, hide from Continue Watching. Views only pass navigation / openURL.
//

import Foundation
import KinoPubBackend
import KinoPubUI
import OSLog
import KinoPubLogging

@MainActor
final class MediaCardMenuCoordinator: ObservableObject {

  @Published private(set) var folders: [Bookmark] = []
  /// Folder ids that currently contain each item. **Not** `@Published`: filling this
  /// from a Home/shelf context-menu builder used to republish on every card, which
  /// re-entered `MediaRowsView` body, re-fired `get-item-folders` for every visible
  /// poster, and froze the Mac UI (`NavigationRequestObserver` thrash + blank artwork).
  /// Mutated silently for cache fills; call sites that need a redraw (toggle) send
  /// `objectWillChange` themselves via the `@Published` paths below.
  private(set) var membershipByItemID: [Int: Set<Int>] = [:]
  /// When set, the hosting view should present the New Folder alert for this item.
  @Published var newFolderItemID: Int?
  @Published var newFolderName: String = ""

  private let contentService: VideoContentService
  private let actionsService: UserActionsService
  private let contentStore: ContentStore
  private weak var errorHandler: ErrorHandler?
  private var membershipTasks: [Int: Task<Void, Never>] = [:]

  init(contentService: VideoContentService,
       actionsService: UserActionsService,
       contentStore: ContentStore) {
    self.contentService = contentService
    self.actionsService = actionsService
    self.contentStore = contentStore
  }

  /// Convenience from the shared app context. Call `bind(errorHandler:)` from the view.
  convenience init(appContext: AppContextProtocol = AppContext.shared) {
    self.init(contentService: appContext.contentService,
              actionsService: appContext.actionsService,
              contentStore: appContext.contentStore)
  }

  func bind(errorHandler: ErrorHandler) {
    self.errorHandler = errorHandler
  }

  func refreshFolders() async {
    do {
      folders = try await contentService.fetchBookmarks().items.recentlyUpdatedFirst()
    } catch {
      Logger.app.debug("MediaCardMenu folders failed: \(error)")
    }
  }

  /// Warm membership for one item. Safe to call from a **menu-open** path only —
  /// never from a SwiftUI body / `contextMenuProvider` that runs per visible card.
  /// Writes the cache without publishing so a burst of prefetches cannot invalidate Home.
  func prefetchMembership(for itemID: Int) {
    guard membershipByItemID[itemID] == nil else { return }
    guard membershipTasks[itemID] == nil else { return }
    membershipTasks[itemID] = Task { [weak self] in
      await self?.refreshMembership(for: itemID, publish: false)
      self?.membershipTasks[itemID] = nil
    }
  }

  func refreshMembership(for itemID: Int, publish: Bool = true) async {
    do {
      let folders = try await contentService.fetchItemFolders(itemId: itemID).items
      membershipByItemID[itemID] = Set(folders.map(\.id))
    } catch {
      Logger.app.debug("MediaCardMenu membership \(itemID) failed: \(error)")
      if membershipByItemID[itemID] == nil {
        membershipByItemID[itemID] = []
      }
    }
    if publish { objectWillChange.send() }
  }

  func promptNewFolder(for itemID: Int) {
    newFolderName = ""
    newFolderItemID = itemID
  }

  func cancelNewFolder() {
    newFolderItemID = nil
    newFolderName = ""
  }

  func confirmNewFolder() {
    let title = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let itemID = newFolderItemID, !title.isEmpty else {
      cancelNewFolder()
      return
    }
    newFolderItemID = nil
    newFolderName = ""
    Task {
      do {
        let folderId = try await actionsService.createBookmarkFolder(title: title)
        try await contentService.toggleBookmark(itemId: itemID, folderId: folderId)
        var set = membershipByItemID[itemID] ?? []
        set.insert(folderId)
        membershipByItemID[itemID] = set
        objectWillChange.send()
        await refreshFolders()
        contentStore.invalidate(family: .bookmarks)
      } catch {
        errorHandler?.setError(error)
      }
    }
  }

  // MARK: - Actions

  func play(_ card: MediaCard, push: @escaping (Route) -> Void) {
    Task {
      do {
        let item = try await contentService.fetchDetails(for: "\(card.itemID)").item
        push(.player(playable(from: item, preferring: card)))
      } catch {
        errorHandler?.setError(error)
      }
    }
  }

  func toggleWatchlist(_ card: MediaCard) {
    Task {
      do {
        try await actionsService.toggleWatchlist(id: card.itemID)
        contentStore.invalidate(family: .watch)
      } catch {
        errorHandler?.setError(error)
      }
    }
  }

  func toggleBookmark(itemID: Int, folder: Bookmark) {
    var set = membershipByItemID[itemID] ?? []
    if set.contains(folder.id) {
      set.remove(folder.id)
    } else {
      set.insert(folder.id)
    }
    membershipByItemID[itemID] = set
    objectWillChange.send()
    Task {
      do {
        try await contentService.toggleBookmark(itemId: itemID, folderId: folder.id)
        contentStore.invalidate(family: .bookmarks)
      } catch {
        await refreshMembership(for: itemID, publish: true)
        errorHandler?.setError(error)
      }
    }
  }

  /// Mark watched / new. `removeFromContinueWatching` for CW / episode rails only.
  func toggleWatched(_ card: MediaCard, removeFromContinueWatching: Bool) {
    let video = card.video ?? (card.isSeries ? nil : 1)
    guard let video else { return }
    if removeFromContinueWatching {
      contentStore.removeCard(id: card.id, from: .continueWatching)
      AppContext.shared.localProgressStore.clear(id: card.itemID)
    }
    Task {
      do {
        try await actionsService.toggleWatching(id: card.itemID, video: video, season: card.season)
        contentStore.invalidate(family: .watch)
      } catch {
        errorHandler?.setError(error)
        if removeFromContinueWatching {
          contentStore.invalidate(family: .watch)
        }
      }
    }
  }

  func hideFromContinueWatching(_ card: MediaCard) {
    contentStore.removeCard(id: card.id, from: .continueWatching)
    AppContext.shared.localProgressStore.clear(id: card.itemID)
    Task {
      do {
        try await actionsService.clearHistoryForItem(id: card.itemID)
      } catch {
        errorHandler?.setError(error)
        contentStore.invalidate(family: .watch)
      }
    }
  }

  // MARK: - Play target

  private func playable(from item: MediaItem, preferring card: MediaCard) -> any PlayableItem {
    if let seasonNum = card.season, let video = card.video,
       let season = item.seasons?.first(where: { $0.number == seasonNum }),
       let episode = season.episodes.first(where: { $0.number == video }) {
      episode.seasonNumber = season.number
      episode.mediaId = season.mediaId
      episode.seriesTitle = item.localizedTitle
      return episode
    }
    if let (season, episode) = item.primaryEpisode {
      episode.seasonNumber = season.number
      episode.mediaId = season.mediaId
      episode.seriesTitle = item.localizedTitle
      return episode
    }
    return item
  }
}
