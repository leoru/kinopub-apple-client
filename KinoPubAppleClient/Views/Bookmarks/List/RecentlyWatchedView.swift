//
//  RecentlyWatchedView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Sidebar tab wrapper around `HistoryView` with its own stack so links do not
/// steal Home's `mainRoutes` path.
struct RecentlyWatchedView: View {
  @EnvironmentObject var navigationState: NavigationState
  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  var body: some View {
    RouteStack(tab: .recentlyWatched) {
      HistoryView()
    }
  }

}
