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
import Combine

@MainActor
class DownloadsCatalog: ObservableObject {
  
  private var downloadsDatabase: DownloadedFilesDatabase<MediaItem>
  private var downloadManager: DownloadManager<MediaItem>
  
  @Published public var downloadedItems: [DownloadedFileInfo<MediaItem>] = []
  @Published public var activeDownloads: [Download<MediaItem>] = []
  
  var cancellables = [AnyCancellable]()
  
  var isEmpty: Bool {
    downloadedItems.isEmpty && activeDownloads.isEmpty
  }
  
  init(downloadsDatabase: DownloadedFilesDatabase<MediaItem>, downloadManager: DownloadManager<MediaItem>) {
    self.downloadsDatabase = downloadsDatabase
    self.downloadManager = downloadManager
  }
  
  func refresh() {
    self.downloadedItems = downloadsDatabase.readData() ?? []
    self.activeDownloads = downloadManager.activeDownloads.map({ $0.value })
    cancellables.removeAll()
    self.activeDownloads.forEach({
      let c = $0.objectWillChange.sink(receiveValue: { self.objectWillChange.send() })
      self.cancellables.append(c)
    })
    
  }
  
  func deleteDownloadedItem(at indexSet: IndexSet) {
    for index in indexSet {
      let item = downloadedItems[index]
      downloadsDatabase.remove(fileInfo: item)
    }
  }
  
  func deleteActiveDownload(at indexSet: IndexSet) {
    for index in indexSet {
      let item = activeDownloads[index]
      downloadManager.removeDownload(for: item.url)
    }
  }
  
  func toggle(download: Download<MediaItem>) {
    if download.state == .inProgress {
      download.pause()
    } else {
      download.resume()
    }
  }
}
