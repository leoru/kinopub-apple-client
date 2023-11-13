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
  @EnvironmentObject var navigationState: NavigationState
  
  init(manager: @autoclosure @escaping () -> PlayerManager) {
    _playerManager = StateObject(wrappedValue: manager())
  }
  
  var body: some View {
    GeometryReader { _ in
      ZStack(alignment: .top) {
        videoPlayer
        backButton
        if let continueTime = playerManager.continueTime {
          continueWatching(to: continueTime)
        }
      }
      .ignoresSafeArea(.all)
    }
    .ignoresSafeArea(.all)
#if os(macOS)
    .toolbar(.hidden, for: .windowToolbar)
    .onAppear(perform: {
      toggleSidebar()
    })
#endif
#if os(iOS)
    .navigationBarHidden(true)
    .toolbar(.hidden, for: .tabBar)
    .onChange(of: playerManager.isPlaying) { isPlaying in
      hideNavigationBar = isPlaying
    }
    .onAppear(perform: {
      UIApplication.shared.isIdleTimerDisabled = true
      UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
      AppDelegate.orientationLock = .landscape
      toggleSidebar()
      Task {
        await playerManager.fetchWatchMark()
      }
    })
    .onDisappear(perform: {
      UIApplication.shared.isIdleTimerDisabled = false
      AppDelegate.orientationLock = .all
      UIDevice.current.setValue(UIDevice.current.orientation.rawValue, forKey: "orientation")
      UIViewController.attemptRotationToDeviceOrientation()
    })
#endif
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
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      .frame(width: 70, height: 50)
      .padding(.leading, 16)
      .padding(.top, 16)
      Spacer()
    }
    .fixedSize(horizontal: false, vertical: true)
    .opacity(hideNavigationBar ? 0.0 : 1.0)
  }
  
  func continueWatching(to continueTime: TimeInterval) -> some View {
    VStack(alignment: .center) {
      Spacer()
      PlayerContinueWatchingView(time: continueTime, onContinueWatching: {
        playerManager.seekToContinueWatching()
      }, onCancelContinueWatching: {
        playerManager.cancelContinueWatching()
      })
      .frame(width: 180, height: 50)
      .padding(.bottom, 50)
    }
    
  }
  
  private func toggleSidebar() {
    navigationState.columnVisibility = .detailOnly
  }
}
