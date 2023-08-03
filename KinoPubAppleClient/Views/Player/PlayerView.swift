//
//  PlayerView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import SwiftUI
import AVKit

struct PlayerView: View {
  
  @StateObject private var playerManager: PlayerManager
  
  init(manager: @autoclosure @escaping () -> PlayerManager) {
    _playerManager = StateObject(wrappedValue: manager())
  }
  
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        VideoPlayer(player: playerManager.player)
          .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)

      }
    }.ignoresSafeArea(.all)
      .toolbar(.hidden, for: .tabBar)
  }
}
