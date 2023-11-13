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
import KinoPubLogging
import OSLog

enum WatchMode {
  case media
  case trailer
}

class PlayerManager: ObservableObject {
  
  @Published var isPlaying: Bool = false
  @Published var watchMark: WatchData?
  @Published var continueTime: TimeInterval?
  
  lazy var player = AVPlayer(url: fileURL)
  var playItem: any PlayableItem
  private var watchMode: WatchMode
  
  private var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  private var rateObservation: NSKeyValueObservation?
  private var actionsService: UserActionsService
  
  private var fileURL: URL {
    switch watchMode {
    case .media:
      let downloadedFiles = downloadedFilesDatabase.readData()
      if let file = downloadedFiles?.filter({ $0.metadata.id == playItem.id }).first {
        return file.localFileURL
      }
      return URL(string: BestVideoQualityFinder.findBestURL(for: playItem.files))!
    case .trailer:
      return URL(string: playItem.trailer?.url ?? "")!
    }
  }
  
  init(playItem: any PlayableItem,
       watchMode: WatchMode,
       downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>,
       actionsService: UserActionsService) {
    self.playItem = playItem
    self.watchMode = watchMode
    self.actionsService = actionsService
    self.downloadedFilesDatabase = downloadedFilesDatabase
    rateObservation = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      self?.isPlaying = player.rate > 0
    }
  }
  
  func fetchWatchMark() async {
    do {
      watchMark = try await actionsService.fetchWatchMark(id: playItem.metadata.id, video: playItem.metadata.video, season: playItem.metadata.season)
      if let watchMark {
        self.continueTime = watchMark.videos?.first?.time ?? watchMark.seasons?.first?.episodes.first?.time
      }
    } catch {
      Logger.app.error("Failed to fetch watch mark: \(error)")
    }
  }
  
  func seekToContinueWatching() {
    guard let continueTime else {
      return
    }
    
    let seekTime = CMTime(seconds: continueTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    player.seek(to: seekTime)
    
    self.continueTime = nil
  }
  
  func cancelContinueWatching() {
    self.continueTime = nil
  }
  
}
