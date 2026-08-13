//
//  TabsNavigationView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubKit

/// Primary chrome — classic system `TabView` tab bar on every platform.
///
/// The browse destinations live in **one table** (`browseTabs`); each platform only
/// decides how a tab *labels* itself and which utility ends surround them. Before that
/// they were four hand-written trees that had to be edited in parallel every time a tab
/// changed, which is how the iPad bar's comment ended up describing a shape its own code
/// did not build.
///
/// - **tvOS:** `.tabBarOnly` (top); glyph · word · word · word · word · glyph. Search is
///   the **first** tab (left of Home) — not `role: .search`, which pins trailing.
/// - **macOS:** `.tabBarOnly`; no Settings tab (Settings window / ⌘,); no Search tab —
///   compact trailing toolbar search via `macToolbarSearch()` on each `RouteStack`
///   (Finder/Photos). Return opens Search results.
/// - **iPad:** `.tabBarOnly`; Search glyph **first**, Settings gear last, icon+word in
///   between.
/// - **iPhone:** bottom bar; `Tab(role: .search)` pins Search trailing (HIG).
///
/// Badges are `@available(tvOS, unavailable)` on `TabContent` — verified in the 27.0 SDK
/// interface, not assumed — so only the non-TV bars carry the Library count.
///
/// PARKED (do not re-enable until locked properly per docs/WWDC): `.sidebarAdaptable`,
/// `TabViewCustomization`, custom `NavigationSplitView` sidebars, Home segmented
/// Movies/Series. Prototypes remain in `Views/UILab/`.
struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
  @EnvironmentObject var navigationState: NavigationState
  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var networkMonitor: NetworkMonitor

  @State private var sidebarFolders: [Bookmark] = []
  @State private var watchlistBadgeCount = 0
  @State private var sidebarSyncedAt: Date?
  private static let sidebarSyncTTL: TimeInterval = 120
#if os(macOS)
  @Environment(\.openWindow) private var openWindow
#endif

  var body: some View {
    modernTabs
      .environmentObject(navigationState)
      .environment(errorHandler)
      .environment(\.usesTVUIKitPosters, FeatureFlags.tvUIKitPosters)
      .environment(\.mediaNavigation) { value in
        if let route = value as? Route {
          navigationState.push(route)
        }
      }
      .task(id: authState.phase) {
        guard authState.phase == .signedIn else { return }
        await loadSidebarChrome()
      }
      .onChange(of: navigationState.selectedTab) { _, _ in
        guard authState.phase == .signedIn else { return }
        Task { await syncSidebarFolders() }
      }
      // DESIGN: offline / reachability banner when `networkMonitor.isOnline` flips false.
      .onChange(of: networkMonitor.isOnline) { _, _ in }
  }

  private var tabSelection: Binding<NavigationTabs> {
    Binding(
      get: {
#if os(macOS)
        // Search is not a tab on macOS — TabView only knows browse destinations.
        let tab = navigationState.selectedTab
        if tab == .search || tab == .settings {
          return navigationState.searchReturnTab ?? .home
        }
        return tab
#else
        navigationState.selectedTab
#endif
      },
      set: { newValue in
#if os(macOS)
        if navigationState.selectedTab == .search {
          navigationState.selectBrowseTab(newValue)
          return
        }
#endif
        if newValue == .search {
          if navigationState.selectedTab == .search {
            navigationState.popToRoot(for: .search)
          } else {
            // Remember previous tab so Back can leave Search (toolbar / tab / filter jump).
            navigationState.enterSearch()
          }
          return
        }
        if newValue == navigationState.selectedTab {
          navigationState.popToRoot(for: newValue)
        } else {
          navigationState.selectedTab = newValue
        }
      }
    )
  }

  // MARK: - The tab table

  /// A browse destination in bar order. Search and Settings are deliberately absent:
  /// they are the utility ends, and every platform places them differently.
  private struct TabSpec: Identifiable {
    let tab: NavigationTabs
    let title: LocalizedStringKey
    let systemImage: String
    var id: NavigationTabs { tab }
  }

  private static let browseTabs: [TabSpec] = [
    TabSpec(tab: .home, title: "Home", systemImage: "house.fill"),
    TabSpec(tab: .movies, title: "Movies", systemImage: "movieclapper"),
    TabSpec(tab: .series, title: "Shows", systemImage: "rectangle.stack"),
    TabSpec(tab: .library, title: "Library", systemImage: "rectangle.stack.badge.person.crop")
  ]

  @ViewBuilder
  private func content(for tab: NavigationTabs) -> some View {
    switch tab {
    case .home: homeContent
    case .movies: moviesContent
    case .series: seriesContent
    case .library: libraryContent
    default: EmptyView()
    }
  }

  /// Glyph-only tab label. The title still ships as the accessibility label — dropping
  /// the text is a visual decision, not a reason for VoiceOver to announce nothing.
  private func glyph(_ systemImage: String, label: LocalizedStringKey) -> some View {
    Image(systemName: systemImage)
      .accessibilityLabel(Text(label))
  }

  // MARK: - TabView

  @ViewBuilder
  private var modernTabs: some View {
#if os(macOS)
    macShell
#elseif os(tvOS)
    tvTabBar
#elseif os(iOS)
    if horizontalSizeClass == .regular {
      padTabBar
    } else {
      phoneCompactTabBar
    }
#endif
  }

#if os(macOS)
  /// Browse tabs; trailing toolbar search lives on each tab's stack via
  /// `macToolbarSearch()` — never on `TabView` (that yields the giant under-tab field).
  /// Return in the field opens the Search results surface.
  private var macShell: some View {
    ZStack {
      TabView(selection: tabSelection) {
        ForEach(Self.browseTabs) { spec in
          browseTab(spec)
        }
      }
      .tabViewStyle(.tabBarOnly)
      .opacity(navigationState.selectedTab == .search ? 0 : 1)
      .allowsHitTesting(navigationState.selectedTab != .search)

      if navigationState.selectedTab == .search {
        searchContent
          .background(Color.KinoPub.background)
      }
    }
    .onAppear {
      if navigationState.selectedTab == .settings {
        navigationState.selectedTab = .home
      }
    }
  }
#endif

#if os(tvOS)
  /// Top tab bar — Search is first (left of Home), not `role: .search` (that pins
  /// trailing).
  ///
  /// The browse tabs pass a bare `Text`: `Tab("Title", systemImage:)` gives every tab an
  /// icon+label chip, which is what a 10-foot bar must not be. Only the two utility ends
  /// are glyphs.
  private var tvTabBar: some View {
    TabView(selection: tabSelection) {
      Tab(value: NavigationTabs.search) {
        searchContent
      } label: {
        glyph("magnifyingglass", label: "Search")
      }

      ForEach(Self.browseTabs) { spec in
        Tab(value: spec.tab) {
          content(for: spec.tab)
        } label: {
          Text(spec.title)
        }
      }

      Tab(value: NavigationTabs.settings) {
        settingsContent
      } label: {
        glyph("gear", label: "Settings")
      }
    }
    .tabViewStyle(.tabBarOnly)
  }
#endif

#if os(iOS)
  /// iPad top tab bar: Search glyph leads, Settings gear closes, icon+word in between.
  ///
  /// Search deliberately does **not** use `Tab(role: .search)` here — that role pins it
  /// trailing, which put the two utility tabs at the same end and read as an
  /// afterthought. iPhone keeps the role (bottom-bar HIG).
  private var padTabBar: some View {
    TabView(selection: tabSelection) {
      Tab(value: NavigationTabs.search) {
        searchContent
      } label: {
        glyph("magnifyingglass", label: "Search")
      }

      ForEach(Self.browseTabs) { spec in
        browseTab(spec)
      }

      Tab(value: NavigationTabs.settings) {
        settingsContent
      } label: {
        glyph("gear", label: "Settings")
      }
    }
    .tabViewStyle(.tabBarOnly)
    // Always visible for now (2026-08-09) — the system's scroll-driven minimize was
    // reading as random fade in/out. Revisit once detail-page choreography settles.
    .tabBarMinimizeBehavior(.never)
  }

  /// iPhone bottom bar — content tabs + pinned trailing Search (`Tab(role: .search)`).
  private var phoneCompactTabBar: some View {
    TabView(selection: tabSelection) {
      ForEach(Self.browseTabs) { spec in
        browseTab(spec)
      }

      Tab("Settings", systemImage: "gear", value: NavigationTabs.settings) {
        settingsContent
      }

      Tab(value: NavigationTabs.search, role: .search) {
        searchContent
      } label: {
        Label("Search", systemImage: "magnifyingglass")
      }
    }
    // Always visible for now (2026-08-09) — see `padTabBar`.
    .tabBarMinimizeBehavior(.never)
  }
#endif

#if !os(tvOS)
  /// One browse tab with its badge. Split out because `TabContent.badge` is
  /// `@available(tvOS, unavailable)` — the TV bar builds its tabs without this.
  @TabContentBuilder<NavigationTabs>
  private func browseTab(_ spec: TabSpec) -> some TabContent<NavigationTabs> {
    if spec.tab == .library {
      Tab(spec.title, systemImage: spec.systemImage, value: spec.tab) {
        content(for: spec.tab)
      }
      .badge(libraryBadgeCount)
    } else {
      Tab(spec.title, systemImage: spec.systemImage, value: spec.tab) {
        content(for: spec.tab)
      }
    }
  }
#endif

  // MARK: - Badges

  private var libraryBadgeCount: Int {
    watchlistBadgeCount + bookmarksBadgeCount
  }

  private var bookmarksBadgeCount: Int {
    sidebarFolders.reduce(0) { $0 + (Int($1.count) ?? 0) }
  }

  // MARK: - Tab roots

  private var searchContent: some View {
    SearchView(catalog: LibraryCatalog(itemsService: appContext.contentService,
                                       authState: authState,
                                       errorHandler: errorHandler))
  }

  private var homeContent: some View {
    MainView(catalog: HomeCatalog(itemsService: appContext.contentService,
                                  authState: authState,
                                  errorHandler: errorHandler))
  }

  private var moviesContent: some View {
    CatalogView(title: "Movies",
                tab: .movies,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .movie))
  }

  private var seriesContent: some View {
    CatalogView(title: "Shows",
                tab: .series,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .serial))
  }

  /// macOS and tvOS run the sidebar shell; iOS still gets the shelf-rows Library until
  /// its Podcasts-shaped list lands (`docs/archive/plans/library-sidebar.md`, phase 4).
  @ViewBuilder
  private var libraryContent: some View {
#if os(macOS) || os(tvOS)
    LibraryShellView(
      model: LibraryModel(contentService: appContext.contentService,
                          actionsService: appContext.actionsService,
                          authState: authState,
                          errorHandler: errorHandler),
      catalog: LibrarySectionCatalog(contentService: appContext.contentService,
                                     authState: authState,
                                     errorHandler: errorHandler)
    )
#else
    LibraryView(catalog: PersonalLibraryCatalog(itemsService: appContext.contentService,
                                                authState: authState,
                                                errorHandler: errorHandler))
#endif
  }

#if !os(macOS)
  private var settingsContent: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
  }
#endif

  // MARK: - Badge data

  /// Only the badge counts are fetched here. The profile avatar deliberately is **not**:
  /// `SettingsRootView` already loads and caches it for the one screen that draws it,
  /// and this view's copy fed a `@State` no branch of the body ever rendered — a network
  /// fetch per sign-in for nothing. Left over from the parked sidebar shell.
  private func loadSidebarChrome() async {
    async let foldersTask = fetchFolders()
    async let watchlistTask = fetchWatchlistCount()
    sidebarFolders = await foldersTask
    watchlistBadgeCount = await watchlistTask
    sidebarSyncedAt = Date()
  }

  private func syncSidebarFolders() async {
    if let sidebarSyncedAt, Date().timeIntervalSince(sidebarSyncedAt) < Self.sidebarSyncTTL { return }
    async let foldersTask = fetchFolders()
    async let watchlistTask = fetchWatchlistCount()
    let folders = await foldersTask
    let watchlist = await watchlistTask
    if folders != sidebarFolders { sidebarFolders = folders }
    if watchlist != watchlistBadgeCount { watchlistBadgeCount = watchlist }
    sidebarSyncedAt = Date()
  }

  private func fetchFolders() async -> [Bookmark] {
    do {
      return try await appContext.contentService.fetchBookmarks().items
        .filter { $0.count != "0" }
        .recentlyUpdatedFirst()
    } catch {
      return sidebarFolders
    }
  }

  private func fetchWatchlistCount() async -> Int {
    do {
      return try await appContext.contentService.fetchWatchingSerials(subscribedOnly: true).items.count
    } catch {
      return watchlistBadgeCount
    }
  }
}

/*
 PARKED — sidebarAdaptable / locked-sidebar experiments (revisit with docs + device checks)

 Do not re-enable until sidebar toggle / hide / edit are solved the system way:
 - TabView(.sidebarAdaptable) + TabSection + tabViewSidebarBottomBar / Header
 - TabViewCustomization (macOS hide/reorder) — intentionally omitted before; still open
 - .toolbar(removing: .sidebarToggle) + CommandGroup(replacing: .sidebar)
 - NavigationSplitView + List(selection:) / custom Button rows — rejected vs apple-native-design
 - Home segmented For You/Movies/Series instead of separate tabs

 Working prototypes: Views/UILab/UILabRoot.swift (adaptable vs split).
*/

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
      .environmentObject(NetworkMonitor())
  }
}
