//
//  PlayerView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import SwiftUI
import AVKit
import KinoPubUI

struct PlayerView: View {

  @StateObject private var playerManager: PlayerManager
  @State private var hideNavigationBar = false
  @State private var showsSubtitlePicker = false
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var navigationState: NavigationState

  init(manager: @autoclosure @escaping () -> PlayerManager) {
    _playerManager = StateObject(wrappedValue: manager())
  }

  var body: some View {
    GeometryReader { _ in
      ZStack(alignment: .top) {
        videoPlayer
        playerChrome
        if let continueTime = playerManager.continueTime {
          continueWatching(to: continueTime)
        }
        subtitleLayers
      }
      .ignoresSafeArea(.all)
    }
    .ignoresSafeArea(.all)
    .sheet(isPresented: $showsSubtitlePicker, onDismiss: { playerManager.player.play() }) {
      SubtitleTrackPickerView(tracks: playerManager.subtitleTracks,
                              primary: playerManager.primaryTrack,
                              secondary: playerManager.secondaryTrack,
                              selectPrimary: { playerManager.select(primary: $0) },
                              selectSecondary: { playerManager.select(secondary: $0) })
    }
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
#if os(tvOS)
    .onAppear {
      Task {
        await playerManager.fetchWatchMark()
      }
    }
    .onChange(of: playerManager.isPlaying) { isPlaying in
      hideNavigationBar = isPlaying
    }
#endif
#if os(macOS)
    .onAppear {
      Task {
        await playerManager.fetchWatchMark()
      }
    }
    .onChange(of: playerManager.isPlaying) { isPlaying in
      hideNavigationBar = isPlaying
    }
#endif
  }

  var videoPlayer: some View {
    VideoPlayer(player: playerManager.player)
      .onAppear(perform: {
        playerManager.player.play()
      })
  }

  @ViewBuilder
  private var subtitleLayers: some View {
    VStack {
      Spacer()
      if playerManager.subtitlesEnabled,
         playerManager.isPlaying,
         let cue = playerManager.activeCue {
        SubtitleOverlayView(text: cue.displayText,
                            secondaryText: playerManager.activeSecondaryCue?.displayText)
          .padding(.bottom, 48)
          .transition(.opacity)
      }

      if !playerManager.isPlaying,
         let cue = playerManager.activeCue ?? playerManager.lastCue,
         !cue.displayText.isEmpty {
        SubtitleTranslatePanel(cueText: cue.displayText)
          .padding(.horizontal, 24)
          .padding(.bottom, 56)
          .transition(.opacity)
      }
    }
    .animation(.easeOut(duration: 0.2), value: playerManager.isPlaying)
    .animation(.easeOut(duration: 0.2), value: playerManager.activeCue)
    .animation(.easeOut(duration: 0.2), value: playerManager.activeSecondaryCue)
  }

  var playerChrome: some View {
    HStack(alignment: .top) {
      Button(action: { dismiss() }, label: {
        Image(systemName: "chevron.backward")
          .font(.system(size: 24))
          .tint(Color.KinoPub.accent)
      })
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
      .frame(width: 70, height: 70)
      .padding(.leading, 32)
      .padding(.top, 16)
      .contentShape(Rectangle())
      Spacer()
      if playerManager.canChooseSubtitles {
        subtitlesButton
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .opacity(hideNavigationBar ? 0.0 : 1.0)
    // Invisible chrome must not keep taking focus or taps while playback runs.
    .disabled(hideNavigationBar)
  }

  private var subtitlesButton: some View {
    Button(action: {
      playerManager.player.pause()
      showsSubtitlePicker = true
    }, label: {
      Image(systemName: "captions.bubble")
        .font(.system(size: 24))
        .tint(Color.KinoPub.accent)
    })
#if os(macOS)
    .buttonStyle(PlainButtonStyle())
#endif
    .frame(width: 70, height: 70)
    .padding(.trailing, 32)
    .padding(.top, 16)
    .contentShape(Rectangle())
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
