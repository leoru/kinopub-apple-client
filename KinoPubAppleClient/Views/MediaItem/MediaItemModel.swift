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

  init(mediaItemId: Int,
       itemsService: VideoContentService,
       downloadManager: DownloadManager<DownloadMeta>,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
    self.downloadManager = downloadManager
  }

  func fetchData() {
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = mediaItem.id
        mediaItem.seasons = mediaItem.seasons?.map({ $0.mediaId = mediaId; return $0 })
        itemLoaded = true
      } catch {
        errorHandler.setError(error)
      }
    }
  }
  
  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    _ = downloadManager.startDownload(url: URL(string: file.url.http)!, withMetadata: DownloadMeta.make(from: item))
  }

}
