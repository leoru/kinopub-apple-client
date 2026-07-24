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
#if !os(tvOS)
        // The Menu button leaves the player on tvOS, and subtitles/audio live in the
        // system transport bar — so the hand-rolled chrome only ships off-TV.
        playerChrome
#endif
        subtitleLayers
      }
      .ignoresSafeArea(.all)
    }
    .ignoresSafeArea(.all)
#if !os(tvOS)
    .sheet(isPresented: $showsSubtitlePicker, onDismiss: { playerManager.player.play() }) {
      SubtitleTrackPickerView(tracks: playerManager.subtitleTracks,
                              primary: playerManager.primaryTrack,
                              secondary: playerManager.secondaryTrack,
                              selectPrimary: { playerManager.select(primary: $0) },
                              selectSecondary: { playerManager.select(secondary: $0) })
    }
#endif
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
    // The player is a full-screen surface, not a browse tab — the tab strip has no place
    // over it. Back/Menu leaves, the same as on the detail page.
    .toolbar(.hidden, for: .tabBar)
    .onAppear {
      Task {
        await playerManager.fetchWatchMark()
      }
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

  @ViewBuilder
  var videoPlayer: some View {
#if os(tvOS)
    // The system player screen is the whole point: its transport bar is the only chrome,
    // and it's fully Siri-Remote navigable. `PlayerManager` hangs the title, subtitle and
    // the Subtitles/Audio menus off the controller.
    TVVideoPlayer(manager: playerManager, onMenuPress: { dismiss() })
      .onAppear { playerManager.player.play() }
#else
    VideoPlayer(player: playerManager.player)
      .onAppear(perform: {
        playerManager.player.play()
      })
#endif
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

#if !os(tvOS)
      // Translation is unavailable on tvOS (canImport(Translation) excludes it), so the
      // panel there could only ever say so — and it sat as a SwiftUI overlay above the
      // system AVPlayerViewController, where the Siri Remote could never actually focus
      // its word chips. Not worth shipping a dead control for a feature with no payoff.
      if !playerManager.isPlaying,
         let cue = playerManager.activeCue ?? playerManager.lastCue,
         !cue.displayText.isEmpty {
        SubtitleTranslatePanel(cueText: cue.displayText)
          .padding(.horizontal, 24)
          .padding(.bottom, 56)
          .transition(.opacity)
      }
#endif
    }
    .animation(.easeOut(duration: 0.2), value: playerManager.isPlaying)
    .animation(.easeOut(duration: 0.2), value: playerManager.activeCue)
    .animation(.easeOut(duration: 0.2), value: playerManager.activeSecondaryCue)
  }

#if !os(tvOS)
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
#endif

  private func toggleSidebar() {
    navigationState.columnVisibility = .detailOnly
  }
}

#if os(tvOS)

/// Drives `AVPlayerViewController` directly so the system transport bar is the only
/// chrome — title/subtitle in the info panel, Subtitles and Audio in the transport-bar
/// menu, all reachable with the Siri Remote. `PlayerManager` owns the configuration; this
/// is just the bridge into UIKit.
private struct TVVideoPlayer: UIViewControllerRepresentable {
  let manager: PlayerManager
  /// This controller is a plain `NavigationStack` push, not a full-screen presentation —
  /// so AVKit's own "end full-screen presentation" dismiss path never fires. Menu is
  /// wired to exit through `playerViewControllerShouldDismiss` instead, the delegate
  /// call AVKit makes specifically for a Menu press on an embedded (non-presented)
  /// player, so leaving the player never depends on how the hosting navigation happens
  /// to react to the hardware button.
  let onMenuPress: () -> Void

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = manager.player
    controller.delegate = context.coordinator
    manager.attach(to: controller)
    return controller
  }

  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
    if controller.player !== manager.player {
      controller.player = manager.player
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onMenuPress: onMenuPress)
  }

  final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    let onMenuPress: () -> Void

    init(onMenuPress: @escaping () -> Void) {
      self.onMenuPress = onMenuPress
    }

    func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
      onMenuPress()
      return false
    }
  }
}

#endif
