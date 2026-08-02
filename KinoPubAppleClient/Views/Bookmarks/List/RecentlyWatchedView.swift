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
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  var body: some View {
    NavigationStack(path: $navigationState.recentlyWatchedRoutes) {
      HistoryView()
        .navigationDestination(for: Route.self) { route in
          RouteDestination(route: route, linkProvider: AppRoutesLinkProvider())
        }
    }
    .navigationStackActive(for: .recentlyWatched, selected: navigationState.selectedTab)
  }

}
