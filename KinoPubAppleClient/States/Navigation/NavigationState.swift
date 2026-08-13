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

/*
 PARKED — HomeBrowseSegment (macOS sidebar Home + For You/Movies/Series segmented).
 Only needed if we revive sidebarAdaptable / locked Home without Movies/Shows tabs.
 enum HomeBrowseSegment: String, CaseIterable, Identifiable, Hashable {
   case forYou, movies, series
 }
*/

class NavigationState: ObservableObject {
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
#if os(macOS)
  /// Shared with the always-visible trailing toolbar search field (Finder/Photos style).
  @Published var macSearchFieldText = ""
  /// Recent queries for the searchable suggestion menu (Photos-style dropdown).
  @Published private(set) var macSearchRecents: [String] = MacSearchRecentsStore.load()
#endif

#if os(macOS)
  /// Bumped instead of appending whenever `push` redirects a `.player` / `.trailerPlayer`
  /// route to the dedicated window (see `push`). `RootView` holds the `openWindow`
  /// environment action and observes this to actually raise that window — `NavigationState` is a
  /// plain `ObservableObject`, not a view, so it cannot call `openWindow` itself. A fresh
  /// UUID on every redirect makes a repeat request for the same item still fire the
  /// observer.
  @Published private(set) var playerWindowRequestID: UUID?
#endif

  var canReturnFromSearch: Bool { searchReturnTab != nil }

  /// Switch to Search with a filter already selected (and the stack at root).
  func openSearch(filter: LibraryFilter, title: String) {
    if selectedTab != .search {
      searchReturnTab = selectedTab
    }
    pendingSearch = PendingSearch(filter: filter, title: title)
    searchRoutes = []
#if os(macOS)
    macSearchFieldText = title
    rememberMacSearchRecent(title)
#endif
    selectedTab = .search
  }

  /// Focus the search surface (toolbar field / Search tab) without a preselected filter.
  func enterSearch() {
    if selectedTab != .search {
      searchReturnTab = selectedTab
    }
    selectedTab = .search
  }

#if os(macOS)
  /// Finder/Photos pattern: typing stays on the current tab; Return opens Search results.
  func submitToolbarSearch() {
    let query = macSearchFieldText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return }
    rememberMacSearchRecent(query)
    enterSearch()
  }

  func clearMacSearchRecents() {
    macSearchRecents = []
    MacSearchRecentsStore.save([])
  }

  private func rememberMacSearchRecent(_ raw: String) {
    let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return }
    var next = macSearchRecents.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
    next.insert(query, at: 0)
    if next.count > MacSearchRecentsStore.limit {
      next = Array(next.prefix(MacSearchRecentsStore.limit))
    }
    macSearchRecents = next
    MacSearchRecentsStore.save(next)
  }
#endif

  /// Leave Search and restore the tab the filter jump came from.
  func returnFromSearch() {
    guard let tab = searchReturnTab else {
      selectedTab = .home
#if os(macOS)
      macSearchFieldText = ""
#endif
      return
    }
    searchReturnTab = nil
    pendingSearch = nil
#if os(macOS)
    macSearchFieldText = ""
#endif
    selectedTab = tab
  }

  /// Leave Search for an explicit browse tab (toolbar tab click while Search is up).
  func selectBrowseTab(_ tab: NavigationTabs) {
    searchReturnTab = nil
    pendingSearch = nil
    searchRoutes = []
#if os(macOS)
    macSearchFieldText = ""
#endif
    selectedTab = tab
  }

  /// Which array backs which tab. One table, because `push` and `popToRoot` used to
  /// carry a `switch` each over the same ten cases — two places to forget a tab in.
  /// `.settings` has no shared stack: tvOS Settings owns a local `NavigationPath`.
  private static func routes(for tab: NavigationTabs) -> ReferenceWritableKeyPath<NavigationState, [Route]>? {
    switch tab {
    case .search: \.searchRoutes
    case .home: \.mainRoutes
    case .movies: \.moviesRoutes
    case .series: \.seriesRoutes
    case .library: \.libraryRoutes
    case .watchlist: \.watchlistRoutes
    case .recentlyWatched: \.recentlyWatchedRoutes
    case .bookmarks, .bookmark: \.bookmarksRoutes
    case .downloads: \.downloadsRoutes
    case .settings: nil
    }
  }

  /// The path a tab's `NavigationStack` binds to. A tab with no shared stack gets an
  /// inert binding rather than a crash — see `routes(for:)`.
  func path(for tab: NavigationTabs) -> Binding<[Route]> {
    guard let keyPath = Self.routes(for: tab) else {
      return .constant([])
    }
    return Binding(get: { self[keyPath: keyPath] },
                   set: { self[keyPath: keyPath] = $0 })
  }

  /// Clears the selected tab's stack so a second click on the same tab
  /// returns to that tab's root (Apple Music / Apple TV behaviour).
  func popToRoot(for tab: NavigationTabs) {
    guard let keyPath = Self.routes(for: tab) else { return }
    self[keyPath: keyPath] = []
  }

  /// Appends onto the selected tab's navigation stack (context-menu Play, etc.).
  ///
  /// `.player` / `.trailerPlayer` never join that stack on macOS — the player is always
  /// its own window there (see `ROADMAP.md`, "macOS
  /// presentation"). Every push-based Play entry point (card context menus, etc.) goes
  /// through this one function, so redirecting here covers all of them without having to
  /// track down each call site individually.
  @MainActor
  func push(_ route: Route) {
#if os(macOS)
    switch route {
    case .player(let item):
      PlaybackWindowState.shared.request = PlaybackWindowState.Request(item: item, mode: .media)
      playerWindowRequestID = UUID()
      return
    case .trailerPlayer(let item):
      PlaybackWindowState.shared.request = PlaybackWindowState.Request(item: item, mode: .trailer)
      playerWindowRequestID = UUID()
      return
    default:
      break
    }
#endif
    guard let keyPath = Self.routes(for: selectedTab) else { return }
    self[keyPath: keyPath].append(route)
  }
}

extension View {
  /// Sibling `NavigationStack`s in one column can steal `NavigationLink`s when multiple
  /// tab roots stay mounted. Only the selected tab may expose a stack; classic tab bars
  /// already isolate content on most platforms. Keep the root mounted so `@StateObject`
  /// catalogs survive switches.
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

#if os(macOS)
enum MacSearchRecentsStore {
  static let limit = 8
  private static let key = "macSearchRecents"

  static func load() -> [String] {
    UserDefaults.standard.stringArray(forKey: key) ?? []
  }

  static func save(_ values: [String]) {
    UserDefaults.standard.set(values, forKey: key)
  }
}

extension View {
  /// Finder/Photos: compact trailing toolbar search on a `NavigationStack` (never on
  /// `TabView` — that renders a giant under-tab field). Use `placement: .toolbar`
  /// (probe-confirmed on macOS 26/27 with `.tabBarOnly`). Suggestions open as a menu
  /// under the field; Return opens the Search results surface.
  func macToolbarSearch() -> some View {
    modifier(MacToolbarSearchModifier())
  }
}

private struct MacToolbarSearchModifier: ViewModifier {
  @EnvironmentObject private var navigationState: NavigationState

  func body(content: Content) -> some View {
    content
      // Probe: `.toolbar` = compact trailing field beside `.tabBarOnly` tabs (Finder/Photos).
      // `.automatic` / no placement on this shell can still stretch; `.toolbarPrincipal` is the giant center field.
      .searchable(
        text: $navigationState.macSearchFieldText,
        placement: .toolbar,
        prompt: "Search"
      ) {
        if !navigationState.macSearchRecents.isEmpty {
          Section("Recents") {
            ForEach(navigationState.macSearchRecents, id: \.self) { recent in
              Text(recent).searchCompletion(recent)
            }
            Button("Clear") {
              navigationState.clearMacSearchRecents()
            }
          }
        }
      }
      .onSubmit(of: .search) {
        navigationState.submitToolbarSearch()
      }
  }
}
#endif
