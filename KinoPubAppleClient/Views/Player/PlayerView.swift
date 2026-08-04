//
//  PlayerView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import SwiftUI
import AVKit
import KinoPubBackend
import KinoPubUI

struct PlayerView: View {

  @ObservedObject private var playerManager: PlayerManager
  @Environment(\.dismiss) private var dismiss
  @State private var showsFailureAlert = false
#if os(macOS)
  @Environment(\.dismissWindow) private var dismissWindow
#endif

  init(manager: PlayerManager) {
    _playerManager = ObservedObject(wrappedValue: manager)
  }

  var body: some View {
    ZStack(alignment: .top) {
      videoPlayer
      // Off tvOS there is no chrome of ours at all: the system player already draws a
      // transport bar, a subtitle menu and an audio menu, and the master playlist
      // carries every kino.pub subtitle as a real HLS rendition for it to list. Ours
      // was a second subtitles button next to the system one.
#if os(tvOS)
      subtitleLayers
#endif
    }
    .ignoresSafeArea(.all)
    // The system player draws its own chrome for everything else — a spinner while it
    // buffers, Done/Menu/the window close button to get out. The one thing it can't
    // show on its own is *why* a stream failed, so that alone gets a system alert, and
    // we stay in the player rather than bouncing back to the page underneath it.
    .alert("Couldn't Load", isPresented: $showsFailureAlert, presenting: failureMessage) { _ in
      Button("OK", role: .cancel) {}
    } message: { message in
      Text(message)
    }
    .onChange(of: playerManager.playbackState) { _, state in
      if case .failed = state { showsFailureAlert = true }
    }
#if os(macOS)
    // The player has its own window (see `PlayerLink`), so the title bar stays: it
    // carries the film's name and the close button. It used to be hidden while the
    // player was pushed into the main window's detail column, which left the screen
    // with no way out at all once playback hid the custom chevron.
    .navigationTitle(playerManager.displayTitle ?? "")
    // Escape leaves, the way it does out of full-screen video everywhere else. ⌘W still
    // works too, and now closes the film rather than the app's window.
    .onExitCommand {
      dismissWindow(id: PlaybackWindowState.windowID)
    }
#endif
#if os(iOS)
    .navigationBarHidden(true)
    .toolbar(.hidden, for: .tabBar)
    .onAppear(perform: {
      UIApplication.shared.isIdleTimerDisabled = true
      UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
      AppDelegate.orientationLock = .landscape
      Task {
        await playerManager.fetchWatchMark()
      }
    })
    .onDisappear(perform: {
      UIApplication.shared.isIdleTimerDisabled = false
      AppDelegate.orientationLock = .all
      UIDevice.current.setValue(UIDevice.current.orientation.rawValue, forKey: "orientation")
      Self.requestSupportedOrientationsUpdate()
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
    // Closing the window has to stop the sound with it. Only safe to hang off
    // `onDisappear` on macOS: on iOS this view stays mounted underneath AVKit's
    // full-screen presentation, and pausing there would stop playback on the way in.
    .onDisappear {
      playerManager.player.pause()
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
      .task {
        await playerManager.preparePlayback()
        playerManager.player.play()
      }
#elseif os(iOS)
    // `entersFullScreenWhenPlaybackBegins` is what gets us the system Done button: AVKit
    // lifts the controller into its own full-screen presentation, which is the only place
    // it draws one. Tapping Done tells us through the delegate, and we leave the route
    // rather than dropping the user back onto a letterboxed inline player.
    SystemVideoPlayer(player: playerManager.player, onExitFullScreen: { dismiss() })
      .task {
        await playerManager.preparePlayback()
        playerManager.player.play()
      }
#else
    // SwiftUI's `VideoPlayer` exposes none of `speeds` / `allowsPictureInPicturePlayback` /
    // `controlsStyle` on macOS — `AVPlayerView` is the only surface that does (see the
    // customization-surface table in player-and-media.md).
    MacVideoPlayer(player: playerManager.player)
      .task {
        await playerManager.preparePlayback()
        playerManager.player.play()
      }
#endif
  }

#if os(iOS)
  /// Asks the key window's top view controller to re-evaluate
  /// `AppDelegate.supportedInterfaceOrientationsFor` after the player unlocks rotation.
  private static func requestSupportedOrientationsUpdate() {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes
      .first(where: { $0.activationState == .foregroundActive })?
      .windows.first(where: \.isKeyWindow)
      ?? scenes.flatMap(\.windows).first(where: \.isKeyWindow)
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    top?.setNeedsUpdateOfSupportedInterfaceOrientations()
  }
#endif

  /// `nil` outside `.failed`, so the alert's `presenting:` item controls its own
  /// visibility together with `showsFailureAlert`.
  private var failureMessage: String? {
    if case .failed(let message) = playerManager.playbackState {
      return message
    }
    return nil
  }

  /// tvOS only. Sidecar SRT rendered by us, because the Siri Remote path still routes
  /// subtitle choice through `transportBarCustomMenuItems`.
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
    }
    .animation(.easeOut(duration: 0.2), value: playerManager.isPlaying)
    .animation(.easeOut(duration: 0.2), value: playerManager.activeCue)
    .animation(.easeOut(duration: 0.2), value: playerManager.activeSecondaryCue)
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
    controller.speeds = AVPlaybackSpeed.systemDefaultSpeeds
    controller.allowsPictureInPicturePlayback = true
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

#if os(iOS)

/// The system player, presented the way AVKit wants to be presented.
///
/// `entersFullScreenWhenPlaybackBegins` makes the controller lift itself out of this
/// inline frame into its own full-screen presentation, and that presentation is the only
/// thing that draws the system Done button — an embedded `AVPlayerViewController`, or the
/// SwiftUI `VideoPlayer` that used to be here, never shows one. Done ends the
/// presentation, which we forward so the route leaves too.
private struct SystemVideoPlayer: UIViewControllerRepresentable {
  let player: AVPlayer
  let onExitFullScreen: () -> Void

  func makeUIViewController(context: Context) -> AVPlayerViewController {
    let controller = AVPlayerViewController()
    controller.player = player
    controller.delegate = context.coordinator
    controller.entersFullScreenWhenPlaybackBegins = true
    controller.exitsFullScreenWhenPlaybackEnds = true
    controller.allowsPictureInPicturePlayback = true
    return controller
  }

  func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
    if controller.player !== player {
      controller.player = player
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onExitFullScreen: onExitFullScreen)
  }

  final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    let onExitFullScreen: () -> Void

    init(onExitFullScreen: @escaping () -> Void) {
      self.onExitFullScreen = onExitFullScreen
    }

    func playerViewController(_ playerViewController: AVPlayerViewController,
                              willEndFullScreenPresentationWithAnimationCoordinator
                              coordinator: UIViewControllerTransitionCoordinator) {
      // Leave alongside the presentation rather than after it, so the inline player
      // never gets a frame on screen on the way out.
      coordinator.animate(alongsideTransition: nil) { [onExitFullScreen] context in
        guard !context.isCancelled else { return }
        onExitFullScreen()
      }
    }
  }
}

#endif

#if os(macOS)

/// The AppKit surface with real chrome knobs — `speeds`, PiP, the full-screen toggle,
/// sharing — none of which SwiftUI's `VideoPlayer` exposes on macOS (see the
/// customization-surface table in player-and-media.md). Still no chrome of ours: every
/// control here is `AVPlayerView`'s own.
private struct MacVideoPlayer: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.player = player
    view.allowsPictureInPicturePlayback = true
    view.showsFullScreenToggleButton = true
    view.showsSharingServiceButton = true
    view.speeds = AVPlaybackSpeed.systemDefaultSpeeds
    return view
  }

  func updateNSView(_ nsView: AVPlayerView, context: Context) {
    if nsView.player !== player {
      nsView.player = player
    }
  }
}

#endif

/// Opens the player wherever the platform puts it, so no call site has to know.
///
/// tvOS and iOS push it onto the navigation stack — on TV the system player screen owns
/// the display and Menu leaves, on iOS AVKit lifts itself full-screen and draws Done.
/// macOS gets its own window, the way the stock TV app takes a film out of the page it
/// was on: the title bar carries the name and the close button, and ⌘W works.
struct PlayerLink<Label: View>: View {

  private let route: any Hashable
  private let item: any PlayableItem
  private let mode: WatchMode
  private let label: Label

#if os(macOS)
  @Environment(\.openWindow) private var openWindow
#endif

  init(route: any Hashable,
       item: any PlayableItem,
       mode: WatchMode,
       @ViewBuilder label: () -> Label) {
    self.route = route
    self.item = item
    self.mode = mode
    self.label = label()
  }

  var body: some View {
#if os(macOS)
    Button {
      PlaybackWindowState.shared.request = PlaybackWindowState.Request(item: item, mode: mode)
      openWindow(id: PlaybackWindowState.windowID)
    } label: {
      label
    }
#else
    NavigationLink(value: route) {
      label
    }
#endif
  }
}

#if os(macOS)

/// What the player window is currently showing. One window: a second film replaces the
/// first rather than piling up, which is what the stock TV app does too.
///
/// Shared rather than injected, following `AppContext.shared`: a `Button` deep in the
/// item page needs to write to it, and threading an `@EnvironmentObject` down for that
/// would crash every preview that doesn't know to inject one.
@MainActor
final class PlaybackWindowState: ObservableObject {

  static let shared = PlaybackWindowState()
  static let windowID = "player"

  struct Request: Identifiable {
    let id = UUID()
    let item: any PlayableItem
    let mode: WatchMode
  }

  @Published var request: Request?
}

/// Contents of the player window. Keyed by request id so opening a different film builds
/// a fresh `PlayerManager` instead of reusing one that has already prepared playback.
struct PlayerWindowContent: View {

  @ObservedObject private var playback = PlaybackWindowState.shared
  @Environment(\.appContext) private var appContext

  var body: some View {
    if let request = playback.request {
      PlayerView(manager: PlaybackSession.shared.play(
        item: request.item,
        mode: request.mode,
        downloadedFilesDatabase: appContext.downloadedFilesDatabase,
        actionsService: appContext.actionsService
      ))
      .id("\(request.item.id)-\(String(describing: request.mode))")
    } else {
      // Reachable by reopening the window from the Window menu after it was closed.
      Text("Nothing is playing")
        .foregroundStyle(.secondary)
        .frame(minWidth: 480, minHeight: 270)
    }
  }
}

#endif
