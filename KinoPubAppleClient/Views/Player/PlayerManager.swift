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
import AVFoundation

@MainActor
class PlayerManager: ObservableObject {

  lazy var player = AVPlayer(url: URL(string: mediaItem.videos?.first?.files.first?.url.hls4 ?? "")!)

  var mediaItem: MediaItem

  init(mediaItem: MediaItem) {
    self.mediaItem = mediaItem
  }

}
