//
//  NavigationState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

/// Filter + display title handed to Search when opening from an item-page chip.
struct PendingSearch: Equatable {
  var filter: LibraryFilter
  var title: String
}

class NavigationState: ObservableObject {
  @Published var columnVisibility = NavigationSplitViewVisibility.automatic
  @Published var selectedTab: NavigationTabs = .home
  @Published var mainRoutes: [Route] = []
  @Published var searchRoutes: [Route] = []
  @Published var moviesRoutes: [Route] = []
  @Published var seriesRoutes: [Route] = []
  @Published var libraryRoutes: [Route] = []
  @Published var watchlistRoutes: [Route] = []
  @Published var recentlyWatchedRoutes: [Route] = []
  @Published var bookmarksRoutes: [Route] = []
  @Published var downloadsRoutes: [Route] = []
  /// Applied once when Search becomes active — genre / country / year from the
  /// item page land here so Search opens already filtered, titled, and labeled.
  @Published var pendingSearch: PendingSearch?
  /// Tab to restore when the user backs out of a filter-driven Search jump.
  @Published private(set) var searchReturnTab: NavigationTabs?

  var canReturnFromSearch: Bool { searchReturnTab != nil }

  /// Switch to Search with a filter already selected (and the stack at root).
  func openSearch(filter: LibraryFilter, title: String) {
    if selectedTab != .search {
      searchReturnTab = selectedTab
    }
    pendingSearch = PendingSearch(filter: filter, title: title)
    searchRoutes = []
    selectedTab = .search
  }

  /// Leave Search and restore the tab the filter jump came from.
  func returnFromSearch() {
    guard let tab = searchReturnTab else { return }
    searchReturnTab = nil
    pendingSearch = nil
    selectedTab = tab
  }

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

  /// Appends onto the selected tab's navigation stack (context-menu Play, etc.).
  func push(_ route: Route) {
    switch selectedTab {
    case .search:
      searchRoutes.append(route)
    case .home:
      mainRoutes.append(route)
    case .movies:
      moviesRoutes.append(route)
    case .series:
      seriesRoutes.append(route)
    case .library:
      libraryRoutes.append(route)
    case .watchlist:
      watchlistRoutes.append(route)
    case .recentlyWatched:
      recentlyWatchedRoutes.append(route)
    case .bookmarks, .bookmark:
      bookmarksRoutes.append(route)
    case .downloads:
      downloadsRoutes.append(route)
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
