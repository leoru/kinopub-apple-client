//
//  NavigationState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

class NavigationState: ObservableObject {
  @Published var columnVisibility = NavigationSplitViewVisibility.automatic
  @Published var selectedTab: NavigationTabs = .home
  @Published var mainRoutes: [MainRoutes] = []
  @Published var searchRoutes: [SearchRoutes] = []
  @Published var moviesRoutes: [CatalogRoutes] = []
  @Published var seriesRoutes: [CatalogRoutes] = []
  @Published var libraryRoutes: [BookmarksRoutes] = []
  @Published var watchlistRoutes: [BookmarksRoutes] = []
  @Published var recentlyWatchedRoutes: [MainRoutes] = []
  @Published var bookmarksRoutes: [BookmarksRoutes] = []
  @Published var downloadsRoutes: [DownloadsRoutes] = []

  /// Clears the selected tab's stack so a second click on the same sidebar/tab
  /// item returns to that tab's root (Apple Music / Apple TV behaviour).
  func popToRoot(for tab: NavigationTabs) {
    switch tab {
    case .search:
      searchRoutes = []
    case .home:
      mainRoutes = []
    case .movies:
      moviesRoutes = []
    case .series:
      seriesRoutes = []
    case .library:
      libraryRoutes = []
    case .watchlist:
      watchlistRoutes = []
    case .recentlyWatched:
      recentlyWatchedRoutes = []
    case .bookmarks, .bookmark:
      bookmarksRoutes = []
    case .downloads:
      downloadsRoutes = []
    case .settings:
      break
    }
  }
}

extension View {
  /// On macOS, `.sidebarAdaptable` keeps every tab's view tree in the same
  /// split-view column. Sibling `NavigationStack`s then steal `NavigationLink`s
  /// (`MainRoutes` hits a `CatalogRoutes` stack and never activates). Only the
  /// selected tab may expose a stack; classic tab bars already isolate content.
  /// The tab root stays mounted so `@StateObject` catalogs survive switches.
  @ViewBuilder
  func navigationStackActive(for tab: NavigationTabs, selected: NavigationTabs) -> some View {
#if os(macOS)
    if selected == tab {
      self
    }
#else
    self
#endif
  }
}
