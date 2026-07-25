//
//  MediaItemModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import KinoPubKit

@MainActor
class MediaItemModel: ObservableObject {

  private var itemsService: VideoContentService
  private var downloadManager: DownloadManager<DownloadMeta>
  private var errorHandler: ErrorHandler
  public var linkProvider: NavigationLinkProvider
  public var mediaItemId: Int
  
  @Published public var mediaItem: MediaItem = MediaItem.mock()
  @Published public var itemLoaded: Bool = false

  /// "More like this", loaded alongside the page. Empty until it arrives, and left
  /// empty when it fails — the section hides itself rather than erroring over the art.
  @Published public var similarItems: [MediaItem] = []

  /// All bookmark folders, and the ids of those already holding this item.
  @Published public var folders: [Bookmark] = []
  @Published public var folderIDsContainingItem: Set<Int> = []
  @Published public var isWatched: Bool = false

  private var actionsService: UserActionsService

  public var isBookmarked: Bool { !folderIDsContainingItem.isEmpty }

  /// - Parameter knownItem: the listing's copy of the item, where the caller has one.
  ///   Only the artwork is used from it — the page waits for the full details before
  ///   drawing anything else, so a stale title or missing seasons can't leak through.
  init(mediaItemId: Int,
       knownItem: MediaItem? = nil,
       itemsService: VideoContentService,
       downloadManager: DownloadManager<DownloadMeta>,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
    self.downloadManager = downloadManager
    self.actionsService = actionsService
    if let knownItem {
      self.mediaItem = knownItem
    }
  }

  func fetchData() {
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = mediaItem.id
        mediaItem.seasons = mediaItem.seasons?.map({ $0.mediaId = mediaId; return $0 })
        isWatched = mediaItem.playbackAction == .playAgain
        itemLoaded = true
      } catch {
        errorHandler.setError(error)
      }
    }
    Task {
      await loadBookmarkState()
    }
    Task {
      await loadSimilar()
    }
  }

  // MARK: - Actions

  /// Bookmark state is secondary to the page, so a failure here is logged rather
  /// than thrown at the user over the artwork.
  private func loadBookmarkState() async {
    do {
      async let allFolders = itemsService.fetchBookmarks().items
      async let itemFolders = itemsService.fetchItemFolders(itemId: mediaItemId).items
      folders = try await allFolders
      folderIDsContainingItem = Set(try await itemFolders.map(\.id))
    } catch {
      Logger.app.error("Failed to load bookmark state for \(self.mediaItemId): \(error)")
    }
  }

  /// Related items are a tail-end extra, so — like the bookmark state — a failure is
  /// logged and swallowed rather than thrown at the user over the artwork.
  private func loadSimilar() async {
    do {
      similarItems = try await itemsService.fetchSimilar(for: "\(mediaItemId)").items
    } catch {
      Logger.app.error("Failed to load similar items for \(self.mediaItemId): \(error)")
    }
  }

  func toggleWatched() {
    if let (season, episode) = mediaItem.primaryEpisode {
      toggleWatched(episode: episode, season: season)
      return
    }
    let previous = isWatched
    isWatched.toggle()
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: 1, season: nil)
      } catch {
        isWatched = previous
        errorHandler.setError(error)
      }
    }
  }

  /// Marks one episode watched/unwatched from the season rail's context menu.
  func toggleWatched(episode: Episode, season: Season) {
    let previous = episode.watched
    episode.watched = previous > 0 ? 0 : 1
    // Force the published item to refresh so the rail redraws checkmarks/progress.
    mediaItem = mediaItem
    isWatched = mediaItem.playbackAction == .playAgain
    Task {
      do {
        let watched = try await actionsService.toggleWatching(id: mediaItemId,
                                                              video: episode.number,
                                                              season: season.number)
        if let watched {
          episode.watched = watched
          mediaItem = mediaItem
          isWatched = mediaItem.playbackAction == .playAgain
        }
      } catch {
        episode.watched = previous
        mediaItem = mediaItem
        isWatched = mediaItem.playbackAction == .playAgain
        errorHandler.setError(error)
      }
    }
  }

  /// Drops the title from history so it stops cluttering Continue Watching.
  func clearFromContinueWatching() {
    Task {
      do {
        try await actionsService.clearHistoryForItem(id: mediaItemId)
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  /// Drops one episode from history so it stops cluttering Continue Watching.
  func hide(episode: Episode, season: Season) {
    Task {
      do {
        try await actionsService.clearHistoryForMedia(id: episode.id)
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  func toggleFolder(_ folder: Bookmark) {
    let previous = folderIDsContainingItem
    if folderIDsContainingItem.contains(folder.id) {
      folderIDsContainingItem.remove(folder.id)
    } else {
      folderIDsContainingItem.insert(folder.id)
    }
    Task {
      do {
        try await itemsService.toggleBookmark(itemId: mediaItemId, folderId: folder.id)
      } catch {
        folderIDsContainingItem = previous
        errorHandler.setError(error)
      }
    }
  }
  
  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    _ = downloadManager.startDownload(url: URL(string: file.url.http)!, withMetadata: DownloadMeta.make(from: item))
  }

}
