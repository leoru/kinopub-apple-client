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
#endif
#if os(tvOS) || os(macOS)
    // **Leaving the player ends the film.** Menu on the TV, closing the window on the
    // Mac: the session outlives this screen by design, so without this the stream ran on
    // with nothing showing it — audio playing over the browse grid on tvOS, a paused-but
    // -still-loaded item on macOS.
    //
    // Only safe to hang off `onDisappear` on these two: on iOS this view stays mounted
    // under AVKit's own full-screen presentation and gets `onDisappear` on the way *in*,
    // so there the exit signal is the player controller's dismissal delegate instead.
    .onDisappear { endPlayback() }
#endif
  }

  /// Ends the session this screen was showing — unless the viewer moved it into Picture
  /// in Picture, which is them keeping the film, not closing it.
  private func endPlayback() {
    guard !playerManager.isPictureInPictureActive else { return }
    forgetWindowRequest(ifSessionEnded: PlaybackSession.shared.stop(playerManager))
  }

  /// macOS: with nothing playing, the window must not sit on a request that would start a
  /// film again. Only when this screen really was the last one, though — swapping films in
  /// an open window takes the outgoing screen down *after* the incoming film has claimed
  /// the session, and clearing there would blank the window on the film that just started.
  private func forgetWindowRequest(ifSessionEnded ended: Bool) {
#if os(macOS)
    guard ended else { return }
    PlaybackWindowState.shared.request = nil
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
    // The system player, presented rather than embedded — that presentation is where the
    // close button comes from. Done ends the film and leaves the route with it.
    SystemVideoPlayer(manager: playerManager, onFinish: {
      endPlayback()
      dismiss()
    })
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
    Coordinator(manager: manager, onMenuPress: onMenuPress)
  }

  final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    private let manager: PlayerManager
    let onMenuPress: () -> Void

    init(manager: PlayerManager, onMenuPress: @escaping () -> Void) {
      self.manager = manager
      self.onMenuPress = onMenuPress
    }

    func playerViewControllerShouldDismiss(_ playerViewController: AVPlayerViewController) -> Bool {
      onMenuPress()
      return false
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
      manager.setPictureInPictureActive(true)
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
      manager.setPictureInPictureActive(false)
    }
  }
}

#endif

#if os(iOS)

/// The system player, presented the way AVKit wants to be presented: modally, full
/// screen, over everything.
///
/// **That presentation is the whole reason there is a way out.** An `AVPlayerViewController`
/// sitting inline in a view hierarchy draws a transport bar and nothing else — no Done, no
/// close button — and this screen hides the navigation bar and swallows the back swipe, so
/// the iPhone ended up with a film that could not be left. `entersFullScreenWhenPlaybackBegins`
/// was supposed to buy the same presentation for free; it did not, so the presentation is
/// asked for outright instead of hoped for.
///
/// The button belongs to AVKit, not to us — the player still draws no chrome of ours.
private struct SystemVideoPlayer: UIViewControllerRepresentable {
  let manager: PlayerManager
  /// Done, or a swipe down, on the presented player.
  let onFinish: () -> Void

  func makeUIViewController(context: Context) -> PlayerPresentationController {
    let host = PlayerPresentationController()
    host.playerController.player = manager.player
    host.playerController.delegate = context.coordinator
    host.playerController.allowsPictureInPicturePlayback = true
    host.playerController.speeds = AVPlaybackSpeed.systemDefaultSpeeds
    // **This is the exit signal, and it is UIKit's rather than AVKit's.** Apple API
    // limitation: `playerViewControllerDidEndDismissalTransition` is marked unavailable in
    // the iOS 26 SDK ("cannot override … which has been marked unavailable"), so the
    // delegate has nothing to say about Done. This stage getting the screen back means the
    // player is gone, which is the same fact from a layer that still exists. Re-probe the
    // delegate on the next SDK.
    host.onPlayerDismissed = { [weak coordinator = context.coordinator] in
      coordinator?.finish()
    }
    return host
  }

  func updateUIViewController(_ host: PlayerPresentationController, context: Context) {
    if host.playerController.player !== manager.player {
      host.playerController.player = manager.player
    }
  }

  /// The route can be popped from elsewhere while the player is up; the presentation is
  /// AVKit's, so it has to be taken down by hand rather than left orphaned over the app.
  static func dismantleUIViewController(_ host: PlayerPresentationController,
                                        coordinator: Coordinator) {
    host.dismissPlayerIfNeeded()
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(manager: manager, onFinish: onFinish)
  }

  final class Coordinator: NSObject, AVPlayerViewControllerDelegate {
    private let manager: PlayerManager
    private let onFinish: () -> Void
    private var didFinish = false

    init(manager: PlayerManager, onFinish: @escaping () -> Void) {
      self.manager = manager
      self.onFinish = onFinish
    }

    /// Leaving happens once, however many times the host reports it.
    func finish() {
      guard !didFinish else { return }
      didFinish = true
      onFinish()
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
      manager.setPictureInPictureActive(true)
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
      manager.setPictureInPictureActive(false)
    }

    /// Starting PiP is the viewer moving the film, not closing it. Keeping the presented
    /// player behind the PiP window means stopping PiP lands them straight back in it —
    /// the alternative is dismissing here and having to rebuild the interface from a
    /// restore callback, on a route that has already gone.
    func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(
      _ playerViewController: AVPlayerViewController
    ) -> Bool {
      false
    }
  }
}

/// Nothing but a stage for the presentation above: it holds the player controller and
/// puts it on screen once it has a window to present from.
final class PlayerPresentationController: UIViewController {

  let playerController = AVPlayerViewController()
  /// Called when the player has been dismissed and this stage is on screen again.
  var onPlayerDismissed: (() -> Void)?
  private var didPresent = false

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    playerController.modalPresentationStyle = .fullScreen
    playerController.modalPresentationCapturesStatusBarAppearance = true
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard presentedViewController == nil else { return }
    guard !didPresent else {
      onPlayerDismissed?()
      return
    }
    didPresent = true
    present(playerController, animated: true)
  }

  func dismissPlayerIfNeeded() {
    guard playerController.presentingViewController != nil else { return }
    playerController.dismiss(animated: false)
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
      PlaybackWindowState.shared.show(item: item, mode: mode)
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

  /// Put a film in the window. **A play for what is already in there is that window coming
  /// forward, not a new screen:** the request identifies the player's view (see
  /// `PlayerWindowContent`), so replacing it would tear the screen down and rebuild it on
  /// top of a stream that is already running.
  func show(item: any PlayableItem, mode: WatchMode) {
    if let request, request.item.id == item.id, request.mode == mode { return }
    request = Request(item: item, mode: mode)
  }
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
      // Keyed by the request, not by what it points at: closing the window ends the
      // session, so playing the *same* film again has to build a new screen with a new
      // `task`. An id made of item + mode is unchanged in that case, and SwiftUI would
      // keep the old screen — a window that never asks anything to play.
      .id(request.id)
    } else {
      // Reachable by reopening the window from the Window menu after it was closed.
      Text("Nothing is playing")
        .foregroundStyle(.secondary)
        .frame(minWidth: 480, minHeight: 270)
    }
  }
}

#endif
