//
//  KinoPubAppleClientApp.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI

enum WindowSize {
  static let macos = CGSize(width: 1280, height: 720)
}

@main
struct KinoPubAppleClientApp: App {
  
  @StateObject var navigationState = NavigationState()
  @StateObject var errorHandler = ErrorHandler()
  @StateObject var authState = AuthState(authService: AppContext.shared.authService,
                                         accessTokenService: AppContext.shared.accessTokenService)
  
#if os(macOS)
  @StateObject var windowSettings = WindowSettings()
#endif
  
#if os(iOS) || os(tvOS)
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif

#if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif

  init() {
    HLSAudioLabeler.removeLegacyTemporaryFiles()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.appContext, AppContext.shared)
        .environmentObject(navigationState)
        .environmentObject(authState)
        .environmentObject(errorHandler)
#if os(macOS)
        .frame(minWidth: WindowSize.macos.width, minHeight: WindowSize.macos.height)
#endif
    }
#if os(macOS)
    .windowResizability(.contentSize)
#endif

#if os(macOS)
    // The player is its own window rather than a page inside the library window, the way
    // the stock TV app lifts a film out of the page it was on. That window's title bar is
    // where the film's name and the close button come from — a pushed player screen had
    // neither, and no way out once playback began.
    Window("Player", id: PlaybackWindowState.windowID) {
      PlayerWindowContent()
        .environment(\.appContext, AppContext.shared)
        .environmentObject(navigationState)
        .environmentObject(authState)
        .environmentObject(errorHandler)
    }
    // Off the Window menu: the only way in is pressing Play. A menu item opens the scene
    // with nothing to play, which is just an empty black window.
    .commandsRemoved()
    // And don't let the system reopen it at launch for the same reason — a restored
    // player window has no film in it.
    .restorationBehavior(.disabled)
    // Free resizing: a film is worth as much of the display as the viewer wants to give it.
    .windowResizability(.automatic)
    // Open at the shape of the video, not at whatever the last window happened to be —
    // a 16:9 film in a wide short window is all black bars. Everything kino.pub serves is
    // 16:9; a different aspect just letterboxes inside a correctly-sized window instead of
    // opening wrong.
    .defaultWindowPlacement { _, context in
      let visible = context.defaultDisplay.visibleRect
      let width = min(visible.width * 0.8, visible.height * 0.8 * (16.0 / 9.0))
      return WindowPlacement(.center, size: CGSize(width: width, height: width * 9.0 / 16.0))
    }

    Settings {
      SettingsView()
        .environmentObject(windowSettings)
    }
#endif
  }
}
