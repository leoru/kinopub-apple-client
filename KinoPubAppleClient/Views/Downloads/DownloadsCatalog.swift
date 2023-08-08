//
//  DownloadsCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import KinoPubKit
import OSLog

@MainActor
class DownloadsCatalog: ObservableObject {
  
  private var downloadsDatabase: DownloadedFilesDatabase<MediaItem>
  private var downloadManager: DownloadManager<MediaItem>
  
  @Published public var downloadedItems: [DownloadedFileInfo<MediaItem>] = []
  @Published public var activeDownloads: [Download<MediaItem>] = []
  
  init(downloadsDatabase: DownloadedFilesDatabase<MediaItem>, downloadManager: DownloadManager<MediaItem>) {
    self.downloadsDatabase = downloadsDatabase
    self.downloadManager = downloadManager
  }
  
  func refresh() {
    self.downloadedItems = downloadsDatabase.readData() ?? []
    self.activeDownloads = downloadManager.activeDownloads.map({ $0.value })
  }
}
