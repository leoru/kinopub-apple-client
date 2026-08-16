//
//  KinoPubAppleClientApp.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubKit
import KinoPubUI

enum WindowSize {
  static let macos = CGSize(width: 960, height: 580)

  /// Opening size on launch, scaled up from `macos` (the enforced minimum) toward
  /// roughly a 1280x880 window instead of letting the system pick its own default.
  static let macosDefault = CGSize(width: macos.width * 4 / 3, height: macos.height * 4 / 3)
}

@main
struct KinoPubAppleClientApp: App {
  
  @StateObject var navigationState = NavigationState()
  @State private var errorHandler = ErrorHandler()
  @StateObject var networkMonitor = NetworkMonitor()
  @StateObject var authState = AuthState(authService: AppContext.shared.authService,
                                         accessTokenService: AppContext.shared.accessTokenService)
  
#if os(macOS)
  @State private var windowSettings = WindowSettings()
#endif
  
#if os(iOS) || os(tvOS)
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif

#if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif

  init() {
    // First thing: the proxy only records requests made after it is installed, and the
    // launch traffic is the whole reason it exists.
    NetworkDiagnostics.start()
    // Restore streaming if it was left on — but never turn it on by default: enabling it
    // is what triggers the local-network permission prompt.
    if UserDefaults.standard.bool(forKey: DiagnosticsSettings.remoteLoggingKey) {
      MainActor.assumeIsolated { NetworkDiagnostics.setRemoteLoggingEnabled(true) }
    }
    HLSAudioLabeler.removeLegacyTemporaryFiles()
#if os(tvOS) && DEBUG
    // One observer under both SwiftUI and UIKit — see `FocusLog.startGlobalTrace`.
    MainActor.assumeIsolated { FocusLog.startGlobalTrace() }
#endif
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.appContext, AppContext.shared)
        .environmentObject(navigationState)
        .environmentObject(authState)
        .environment(errorHandler)
        .environmentObject(networkMonitor)
#if os(macOS)
        .environment(windowSettings)
#endif
        // Dark-only until light is a deliberate pass (modernization Phase 0).
        // Info.plist UIUserInterfaceStyle=Dark covers system chrome; this covers SwiftUI.
        .preferredColorScheme(.dark)
        // Register a readable device identity + advertise HEVC/4K/HDR once authorized
        // so the kino.pub Devices list isn't "unknown / unknown" and streams match
        // what AVPlayer can open.
        .task(id: authState.userState) {
          if authState.userState == .authorized {
            await AppContext.shared.deviceService.registerDeviceIdentity()
            await AppContext.shared.deviceService.syncCapabilities()
          }
        }
#if os(iOS)
        .task {
          await AppContext.shared.downloadNotificationManager.requestPermission()
        }
#endif
#if os(macOS)
        .frame(minWidth: WindowSize.macos.width, minHeight: WindowSize.macos.height)
#endif
    }
#if os(macOS)
    .windowResizability(.contentSize)
    .defaultSize(width: WindowSize.macosDefault.width, height: WindowSize.macosDefault.height)
    // Unified toolbar — system back/forward + trailing search own the chrome with the tab bar.
    .windowToolbarStyle(.unified(showsTitle: false))
    // "New Window" was the File menu's only item, so removing it drops the whole
    // File menu — expected for now. A second library window would duplicate
    // NavigationState, AuthState, etc. per-scene in ways the app doesn't support.
    // File menu comes back once it has a real item (e.g. a new-bookmark-list
    // command, the way the TV app's File menu has New Playlist).
    .commands {
      AboutCommands()
      SettingsCommands()
#if DEBUG
      UILabCommands()
#endif
      CommandGroup(replacing: .newItem) { }
      // Keep for when `.sidebarAdaptable` returns — hide View → Hide Sidebar.
      // Harmless with classic `.tabBarOnly` (no sidebar chrome).
      CommandGroup(replacing: .sidebar) { }
      // Into the system View menu — `CommandMenu("View")` would add a second View.
      ListArrangementCommands()
    }
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
        .environment(errorHandler)
        .environmentObject(networkMonitor)
        .preferredColorScheme(.dark)
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

    // Custom Settings window (not SwiftUI `Settings` scene) so we own the chrome —
    // System Settings–style sidebar + toolbar. Opened via App menu / ⌘, / profile button.
    Window("Settings", id: SettingsWindow.id) {
      SettingsView()
        .environment(\.appContext, AppContext.shared)
        .environment(windowSettings)
        .environmentObject(authState)
        .environment(errorHandler)
        .preferredColorScheme(.dark)
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 720, height: 520)
    .commandsRemoved()

    Window("About KinoPub", id: AboutWindow.id) {
      AboutView()
        .preferredColorScheme(.dark)
    }
    .windowResizability(.contentSize)
    .restorationBehavior(.disabled)
    .commandsRemoved()

#if DEBUG
    // UI labs — A/B chrome (adaptable TabView vs locked NavigationSplitView).
    // Open from Window menu, Advanced Settings, or the in-lab toolbar.
    WindowGroup("UI Lab", id: UILabWindow.id, for: UILabChrome.self) { $chrome in
      UILabRoot(initialChrome: chrome ?? .adaptableSidebar)
        .frame(minWidth: 1100, minHeight: 700)
        .preferredColorScheme(.dark)
    }
    .defaultSize(width: 1200, height: 800)
    .windowResizability(.contentSize)
    .restorationBehavior(.disabled)
#endif
#endif
  }
}

#if os(macOS)
enum SettingsWindow {
  static let id = "settings"
}

enum AboutWindow {
  static let id = "about"
}

private struct AboutCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button("About KinoPub") {
        openWindow(id: AboutWindow.id)
      }
    }
  }
}

/// The View menu's list-arrangement items, shaped the way Finder and Notes shape
/// theirs: named submenus holding a checked list, not a stack of pickers spilled
/// straight into View. Disabled — not hidden — when the front screen has no list to
/// arrange, which is what tells a user the items exist at all.
private struct ListArrangementCommands: Commands {
  @AppStorage(HistoryGrouping.storageKey) private var grouping: String = HistoryGrouping.none.rawValue
  @AppStorage(HistorySectioning.storageKey) private var sectioning: String = HistorySectioning.month.rawValue
  @FocusedValue(\.showsListArrangement) private var showsArrangement: Bool?

  private var isEnabled: Bool { showsArrangement == true }

  var body: some Commands {
    CommandGroup(after: .toolbar) {
      Divider()
      Menu("Group By") {
        Picker("Group By", selection: $grouping) {
          ForEach(HistoryGrouping.allCases) { option in
            Text(LocalizedStringKey(option.titleKey)).tag(option.rawValue)
          }
        }
      .pickerStyle(.inline)
      .labelsHidden()
      }
      .disabled(!isEnabled)

      // Apple's own wording for this shape — Notes calls it "Group By Date".
      Menu("Group By Date") {
        Picker("Group By Date", selection: $sectioning) {
          ForEach(HistorySectioning.allCases) { option in
            Text(LocalizedStringKey(option.titleKey)).tag(option.rawValue)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
      }
      .disabled(!isEnabled)
    }
  }
}

private struct SettingsCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandGroup(replacing: .appSettings) {
      Button("Settings…") {
        openWindow(id: SettingsWindow.id)
      }
      .keyboardShortcut(",", modifiers: .command)
    }
  }
}

#if DEBUG
private struct UILabCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  @AppStorage(HistoryCardLayout.storageKey) private var historyCardLayout: String = HistoryCardLayout.landscape.rawValue

  var body: some Commands {
    // Window menu — next to Settings / About style utility windows.
    CommandGroup(after: .windowArrangement) {
      Divider()
      Button("UI Lab — Navigation Split") {
        openWindow(id: UILabWindow.id, value: UILabChrome.navigationSplit)
      }
      Button("UI Lab — Adaptable Sidebar") {
        openWindow(id: UILabWindow.id, value: UILabChrome.adaptableSidebar)
      }
      Divider()
      // Landscape vs poster tiles in history. An experiment, not a shipped option: it
      // is named after one screen and there is no general list/cards choice behind it
      // yet, so it stays out of the View menu until there is.
      Picker("History Tiles (experiment)", selection: $historyCardLayout) {
        ForEach(HistoryCardLayout.allCases) { layout in
          Text(LocalizedStringKey(layout.titleKey)).tag(layout.rawValue)
        }
      }
      .pickerStyle(.inline)
    }
  }
}
#endif
#endif

