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
  @Environment(\.dismiss) private var dismiss
  
  init(manager: @autoclosure @escaping () -> PlayerManager) {
    _playerManager = StateObject(wrappedValue: manager())
  }
  
  var body: some View {
    GeometryReader { _ in
      ZStack(alignment: .top) {
        videoPlayer
        backButton
      }
      .ignoresSafeArea(.all)
    }
    .ignoresSafeArea(.all)
    .navigationBarHidden(true)
    .onChange(of: playerManager.isPlaying) { isPlaying in
      hideNavigationBar = isPlaying
    }
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
  
  var videoPlayer: some View {
    VideoPlayer(player: playerManager.player)
      .onAppear(perform: {
        playerManager.player.play()
      })
  }
  
  var backButton: some View {
    HStack(alignment: .top) {
      Button(action: { dismiss() }, label: {
        Image(systemName: "chevron.backward")
          .font(.system(size: 24))
          .tint(Color.KinoPub.accent)
      })
      .frame(width: 70, height: 50)
      .padding(.leading, 16)
      .padding(.top, 16)
      Spacer()
    }
    .fixedSize(horizontal: false, vertical: true)
    .opacity(hideNavigationBar ? 0.0 : 1.0)
  }
}
