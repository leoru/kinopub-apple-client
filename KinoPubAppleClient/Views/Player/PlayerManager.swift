//
//  PlayerManager.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import SwiftUI
import Combine
import KinoPubBackend
import KinoPubKit
import AVFoundation

class PlayerManager: ObservableObject {
  
  @Published var isPlaying: Bool = false
  lazy var player = AVPlayer(url: fileURL)
  var mediaItem: MediaItem
  
  private var downloadedFilesDatabase: DownloadedFilesDatabase<MediaItem>
  private var rateObservation: NSKeyValueObservation?
  
  private var fileURL: URL {
    let downloadedFiles = downloadedFilesDatabase.readData()
    if let file = downloadedFiles?.filter({ $0.metadata.id == mediaItem.id }).first {
      return file.originalURL
    }
    
    return URL(string: mediaItem.videos?.first?.files.first?.url.hls4 ?? "")!
  }
  
  init(mediaItem: MediaItem, downloadedFilesDatabase: DownloadedFilesDatabase<MediaItem>) {
    self.mediaItem = mediaItem
    self.downloadedFilesDatabase = downloadedFilesDatabase
    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      self?.isPlaying = player.rate > 0
    }
  }
  
}
