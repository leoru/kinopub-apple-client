//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct RootView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var navigationState: NavigationState
#if os(macOS)
  @Environment(\.openWindow) private var openWindow
#endif

  var body: some View {
    // Swap entirely (not overlay): a live catalog behind the code keeps loading artwork and
    // cycling the hero through the material, and its unauthorized requests toast on a screen
    // you cannot leave. No animated teardown — UIKit's TabView asserts when sidebarAdaptable
    // tabs are removed mid-update ("No view controller matches the UITabBarItem").
    Group {
      if authState.shouldShowAuthentication {
        AuthView(model: AuthModel(authService: appContext.authService, authState: authState))
      } else {
        TabsNavigationView()
      }
    }
    .task {
      await authState.check()
    }
#if os(macOS)
    // `NavigationState.push` redirects `.player` / `.trailerPlayer` routes into
    // `PlaybackWindowState` instead of a stack; this is the one place holding the
    // `openWindow` environment action needed to actually raise that window.
    .onChange(of: navigationState.playerWindowRequestID) { _, requestID in
      guard requestID != nil else { return }
      openWindow(id: PlaybackWindowState.windowID)
    }
#endif
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
