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
  @State private var hideNavigationBar = false
  @State var activeGestures: GestureMask = .subviews

  init(manager: @autoclosure @escaping () -> PlayerManager) {
    _playerManager = StateObject(wrappedValue: manager())
  }

  var body: some View {
    GeometryReader { _ in
      ZStack {
        VideoPlayer(player: playerManager.player)

      }
    }
    .navigationBarHidden(hideNavigationBar)
    .navigationBarTitle("", displayMode: .inline)
    .ignoresSafeArea(.all)
    .toolbar(.hidden, for: .tabBar)
    .onAppear(perform: {
      UIApplication.shared.isIdleTimerDisabled = true
    })
    .onDisappear(perform: {
      UIApplication.shared.isIdleTimerDisabled = false
    })
  }
}
