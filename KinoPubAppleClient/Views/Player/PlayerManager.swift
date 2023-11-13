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
  private var playerTimeObserver: PlayerTimeObserver?
  private var playItem: any PlayableItem
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
      DispatchQueue.main.async {
        self?.isPlaying = player.rate > 0
      }
    }
    
    playerTimeObserver = PlayerTimeObserver(player: player, period: 10.0, timeUpdateHandler: { [weak self] time in
      self?.saveWatchMark(time: time)
    })
  }
  
  // MARK: - Watch marks
  
  func saveWatchMark(time: TimeInterval) {
    Task.detached(priority: .utility) { [unowned self] in
      do {
        try await self.actionsService.markWatch(id: playItem.id, time: Int(time), video: playItem.metadata.video, season: playItem.metadata.season)
      } catch {
        Logger.app.error("Failed to save watch mark: \(error)")
      }
    }
  }
  
  func fetchWatchMark() async {
    do {
      watchMark = try await actionsService.fetchWatchMark(id: playItem.metadata.id, video: playItem.metadata.video, season: playItem.metadata.season)
      if let watchMark {
        let remoteContinueTime = watchMark.item.videos?.first?.time ?? watchMark.item.seasons?.first?.episodes.first?.time
        self.continueTime = remoteContinueTime ?? 0 > 0 ? remoteContinueTime : nil
      }
    } catch {
      Logger.app.error("Failed to fetch watch mark: \(error)")
    }
  }
  
  // MARK: - Continue watching
  
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
