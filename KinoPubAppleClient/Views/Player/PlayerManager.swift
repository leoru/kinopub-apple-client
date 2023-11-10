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

enum WatchMode {
  case media
  case trailer
}

class PlayerManager: ObservableObject {
  
  @Published var isPlaying: Bool = false
  lazy var player = AVPlayer(url: fileURL)
  var playItem: any PlayableItem
  private var watchMode: WatchMode
  
  private var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var rateObservation: NSKeyValueObservation?
  
  private var fileURL: URL {
    switch watchMode {
    case .media:
      let downloadedFiles = downloadedFilesDatabase.readData()
      if let file = downloadedFiles?.filter({ $0.metadata.id == playItem.id }).first {
        return file.localFileURL
      }
      return URL(string: BestVideoQualityFinder.findBestURL(for: playItem.files ?? []))!
    case .trailer:
      return URL(string: playItem.trailer?.url ?? "")!
    }
  }
  
  init(playItem: any PlayableItem,
       watchMode: WatchMode,
       downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>) {
    self.playItem = playItem
    self.watchMode = watchMode
    self.downloadedFilesDatabase = downloadedFilesDatabase
    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      self?.isPlaying = player.rate > 0
    }
  }
  
}
