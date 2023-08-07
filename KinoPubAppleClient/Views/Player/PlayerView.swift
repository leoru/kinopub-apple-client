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
  @State private var navBarHidden = false

  init(manager: @autoclosure @escaping () -> PlayerManager) {
    _playerManager = StateObject(wrappedValue: manager())
  }

  var body: some View {
    GeometryReader { _ in
      ZStack {
        VideoPlayer(player: playerManager.player)
          .ignoresSafeArea(.all)
          .onAppear(perform: {
            playerManager.player.play()
          })
      }
    }
    .navigationBarHidden(hideNavigationBar)
    .navigationBarTitle("", displayMode: .inline)
    .navigationBarHidden(navBarHidden)
    .ignoresSafeArea(.all)
    .toolbar(.hidden, for: .tabBar)
    .onAppear(perform: {
      UIApplication.shared.isIdleTimerDisabled = true
      UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
      AppDelegate.orientationLock = .landscape
    })
    .onDisappear(perform: {
      UIApplication.shared.isIdleTimerDisabled = false
      AppDelegate.orientationLock = .all
      UIDevice.current.setValue(UIDevice.current.orientation.rawValue, forKey: "orientation")
      UIViewController.attemptRotationToDeviceOrientation()
    })
  }
}
