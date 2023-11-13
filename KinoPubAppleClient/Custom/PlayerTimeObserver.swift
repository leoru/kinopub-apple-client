//
//  PlayerTimeObserver.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 13.11.2023.
//

import Foundation
import AVFoundation

class PlayerTimeObserver {
  private weak var player: AVPlayer?
  private var timeObserverToken: Any?
  private var timeUpdateHandler: ((Double) -> Void)?
  private var period: TimeInterval
  
  init(player: AVPlayer, period: TimeInterval, timeUpdateHandler: @escaping (Double) -> Void) {
    self.player = player
    self.period = period
    self.timeUpdateHandler = timeUpdateHandler
    addPeriodicTimeObserver()
  }
  
  private func addPeriodicTimeObserver() {
    guard let player = player else { return }
    
    let timeScale = CMTimeScale(NSEC_PER_SEC)
    let time = CMTime(seconds: period, preferredTimescale: timeScale)
    
    timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue: .global(qos: .userInteractive)) { [weak self] time in
      self?.timeUpdateHandler?(time.seconds)
    }
  }
  
  deinit {
    if let timeObserverToken = timeObserverToken, let player = player {
      player.removeTimeObserver(timeObserverToken)
    }
  }
}
