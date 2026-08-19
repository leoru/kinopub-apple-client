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
  /// When set, the hosting view should present the New Folder alert for this item.
  @Published var newFolderItemID: Int?
  @Published var newFolderName: String = ""

  private let contentService: VideoContentService
  private let actionsService: UserActionsService
  private let contentStore: ContentStore
  private let membership: BookmarkMembershipStore
  private weak var errorHandler: ErrorHandler?

  init(contentService: VideoContentService,
       actionsService: UserActionsService,
       contentStore: ContentStore,
       membership: BookmarkMembershipStore = .shared) {
    self.contentService = contentService
    self.actionsService = actionsService
    self.contentStore = contentStore
    self.membership = membership
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

  /// Bookmark folders, from the store shared by every coordinator in the app.
  ///
  /// Each screen that can show a card menu owns its own coordinator, and each one calls
  /// this on `.task` — so opening the app used to fire `GET /v1/bookmarks` twenty-odd
  /// times for the same 519 bytes, and every navigation fired more. The call sites are
  /// not wrong (a view should be able to ask for what it needs); fetching per-caller
  /// was. `BookmarkFoldersStore` keeps the list across launches and only goes to the
  /// network when it has nothing, so an ordinary screen — a detail page above all —
  /// opens without a bookmarks request at all.
  func refreshFolders() async {
    folders = await BookmarkFoldersStore.shared.ensureLoaded(using: contentService)
      .recentlyUpdatedFirst()
  }

  /// Refetch after a mutation that changed the folder list itself. Every other
  /// coordinator picks the new list up from the store on its next `refreshFolders()`.
  func reloadFolders() async {
    folders = await BookmarkFoldersStore.shared.reload(using: contentService)
      .recentlyUpdatedFirst()
  }

  /// Folder ids that contain this card — local store + `MediaItem.bookmarks` hint on the card.
  /// Never hits the network (`get-item-folders` is gone on purpose).
  func containingFolders(for card: MediaCard) -> Set<Int> {
    membership.folderIDs(for: card.itemID, serverHint: Set(card.bookmarkFolderIDs))
  }

  func containingFolders(itemID: Int, serverHint: Set<Int> = []) -> Set<Int> {
    membership.folderIDs(for: itemID, serverHint: serverHint)
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
        _ = membership.toggle(itemID: itemID, folderID: folderId)
        objectWillChange.send()
        // The folder list itself changed, so this is the one place a card menu is
        // allowed to go and fetch it again.
        await reloadFolders()
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
        // Stamp the seasons before an episode leaves this scope: `/v1/watching*` keys
        // on the item id and an episode carries it only from here.
        item.seasons?.forEach { $0.mediaId = item.id }
        membership.seed(from: item)
        AppContext.shared.localProgressStore.cacheItem(item)
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

  func toggleBookmark(itemID: Int, folder: Bookmark, serverHint: Set<Int> = []) {
    _ = membership.toggle(itemID: itemID, folderID: folder.id, serverHint: serverHint)
    objectWillChange.send()
    Task {
      do {
        try await contentService.toggleBookmark(itemId: itemID, folderId: folder.id)
        contentStore.invalidate(family: .bookmarks)
      } catch {
        // Flip back locally — still no network membership fetch.
        _ = membership.toggle(itemID: itemID, folderID: folder.id)
        objectWillChange.send()
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
