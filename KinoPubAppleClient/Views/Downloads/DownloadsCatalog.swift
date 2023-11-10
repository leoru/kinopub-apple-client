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
  
  private var downloadsDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var downloadManager: DownloadManager<DownloadMeta>
  
  @Published public var downloadedItems: [DownloadedFileInfo<DownloadMeta>] = []
  @Published public var activeDownloads: [Download<DownloadMeta>] = []
  
  var cancellables = [AnyCancellable]()
  
  var isEmpty: Bool {
    downloadedItems.isEmpty && activeDownloads.isEmpty
  }
  
  init(downloadsDatabase: DownloadedFilesDatabase<DownloadMeta>, downloadManager: DownloadManager<DownloadMeta>) {
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
  
  func toggle(download: Download<DownloadMeta>) {
    if download.state == .inProgress {
      download.pause()
    } else {
      download.resume()
    }
  }
}
