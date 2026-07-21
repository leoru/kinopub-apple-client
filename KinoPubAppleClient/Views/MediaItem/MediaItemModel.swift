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

  /// All bookmark folders, and the ids of those already holding this item.
  @Published public var folders: [Bookmark] = []
  @Published public var folderIDsContainingItem: Set<Int> = []
  @Published public var isWatched: Bool = false

  private var actionsService: UserActionsService

  public var isBookmarked: Bool { !folderIDsContainingItem.isEmpty }

  init(mediaItemId: Int,
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

  func toggleWatched() {
    let previous = isWatched
    isWatched.toggle()
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: nil, season: nil)
      } catch {
        isWatched = previous
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
