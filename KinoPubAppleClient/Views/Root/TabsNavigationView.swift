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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Primary chrome — classic system `TabView` tab bar on every platform.
///
/// - **tvOS:** `.tabBarOnly` (top); Search is the **first** tab (left of Home).
/// - **macOS:** `.tabBarOnly`; no Settings tab (Settings window / ⌘,); no Search tab —
///   compact trailing toolbar search via `macToolbarSearch()` on each `NavigationStack`
///   (Finder/Photos). Return opens Search results. System back/forward stay leading.
/// - **iPad:** `.tabBarOnly`; same shape as tvOS — Search glyph **first**, Settings gear
///   last, words in between (no `role: .search`, which would pin Search trailing).
/// - **iPhone:** bottom tab bar; `Tab(role: .search)` pins Search trailing (HIG).
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
  @State private var userData: UserData? = UserProfileCache.shared.loadUser()
  @State private var avatarImage: Image?
  @State private var watchlistBadgeCount = 0
  @State private var downloadsBadgeCount = 0
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
  /// Browse tabs; trailing toolbar search lives on each tab's `NavigationStack` via
  /// `macToolbarSearch()` — never on `TabView` (that yields the giant under-tab field).
  /// Return in the field opens the Search results surface.
  private var macShell: some View {
    ZStack {
      TabView(selection: tabSelection) {
        Tab("Home", systemImage: "house.fill", value: NavigationTabs.home) {
          homeContent
        }
        Tab("Movies", systemImage: "movieclapper", value: NavigationTabs.movies) {
          moviesContent
        }
        Tab("Shows", systemImage: "rectangle.stack", value: NavigationTabs.series) {
          seriesContent
        }
        Tab("Library", systemImage: "rectangle.stack.badge.person.crop", value: NavigationTabs.library) {
          libraryContent
        }
        .badge(libraryBadgeCount)
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
  /// Top tab bar — Search is first (left of Home), not `role: .search` (that pins trailing).
  ///
  /// Shape is icon · text · text · text · text · icon, the way tvOS media apps read:
  /// the two utility ends are glyphs, the browse destinations are words. Giving the
  /// browse tabs a `systemImage` too turns the bar into a row of icon+label chips,
  /// which is what it must not be — so these deliberately pass a bare `Text`.
  private var tvTabBar: some View {
    TabView(selection: tabSelection) {
      Tab(value: NavigationTabs.search) {
        searchContent
      } label: {
        tvIconTab("magnifyingglass", label: "Search")
      }

      Tab(value: NavigationTabs.home) {
        homeContent
      } label: {
        Text("Home")
      }

      Tab(value: NavigationTabs.movies) {
        moviesContent
      } label: {
        Text("Movies")
      }

      Tab(value: NavigationTabs.series) {
        seriesContent
      } label: {
        Text("Shows")
      }

      Tab(value: NavigationTabs.library) {
        libraryContent
      } label: {
        Text("Library")
      }

      Tab(value: NavigationTabs.settings) {
        settingsContent
      } label: {
        tvIconTab("gear", label: "Settings")
      }
    }
    .tabViewStyle(.tabBarOnly)
  }

  /// Glyph-only tab. The title still ships as the accessibility label — dropping the
  /// text is a visual decision, not a reason for VoiceOver to announce nothing.
  private func tvIconTab(_ systemImage: String, label: LocalizedStringKey) -> some View {
    Image(systemName: systemImage)
      .accessibilityLabel(Text(label))
  }
#endif

#if os(iOS)
  /// iPad top tab bar, shaped like the tvOS one: glyph · words · glyph. Search leads
  /// and Settings closes the bar as bare icons; the browse destinations are words.
  ///
  /// Search deliberately does **not** use `Tab(role: .search)` here — that role pins it
  /// trailing, which put the two utility tabs at the same end and read as an
  /// afterthought. iPhone keeps the role (bottom-bar HIG).
  private var padTabBar: some View {
    TabView(selection: tabSelection) {
      Tab(value: NavigationTabs.search) {
        searchContent
      } label: {
        iconTab("magnifyingglass", label: "Search")
      }

      Tab("Home", systemImage: "house.fill", value: NavigationTabs.home) {
        homeContent
      }

      Tab("Movies", systemImage: "movieclapper", value: NavigationTabs.movies) {
        moviesContent
      }

      Tab("Shows", systemImage: "rectangle.stack", value: NavigationTabs.series) {
        seriesContent
      }

      Tab("Library", systemImage: "rectangle.stack.badge.person.crop", value: NavigationTabs.library) {
        libraryContent
      }
      .badge(libraryBadgeCount)

      Tab(value: NavigationTabs.settings) {
        settingsContent
      } label: {
        iconTab("gear", label: "Settings")
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
      Tab("Home", systemImage: "house.fill", value: NavigationTabs.home) {
        homeContent
      }

      Tab("Movies", systemImage: "movieclapper", value: NavigationTabs.movies) {
        moviesContent
      }

      Tab("Shows", systemImage: "rectangle.stack", value: NavigationTabs.series) {
        seriesContent
      }

      Tab("Library", systemImage: "rectangle.stack.badge.person.crop", value: NavigationTabs.library) {
        libraryContent
      }
      .badge(libraryBadgeCount)

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

  /// Glyph-only tab. The title still ships as the accessibility label — dropping the
  /// text is a visual decision, not a reason for VoiceOver to announce nothing.
  private func iconTab(_ systemImage: String, label: LocalizedStringKey) -> some View {
    Image(systemName: systemImage)
      .accessibilityLabel(Text(label))
  }
#endif

  // MARK: - Profile chrome (badges / Settings tab)

  private var profileDisplayName: String {
    userData?.profile.name?.nilIfEmpty
      ?? userData?.username.nilIfEmpty
      ?? "Profile".localized
  }

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
                path: \.moviesRoutes,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .movie))
  }

  private var seriesContent: some View {
    CatalogView(title: "Shows",
                tab: .series,
                path: \.seriesRoutes,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .serial))
  }

  /// macOS and tvOS run the sidebar shell; iOS still gets the shelf-rows Library until
  /// its Podcasts-shaped list lands (`docs/en/plans/library-sidebar.md`, phase 4).
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

  // MARK: - Badge / profile data

  private func loadSidebarChrome() async {
    if avatarImage == nil, let cachedAvatar = UserProfileCache.shared.loadAvatar() {
      avatarImage = Self.platformImage(from: cachedAvatar)
    }

    async let userTask: UserData? = {
      try? await appContext.userService.fetchUserData()
    }()
    async let foldersTask = fetchFolders()
    async let watchlistTask = fetchWatchlistCount()

    if let freshUser = await userTask {
      userData = freshUser
      UserProfileCache.shared.save(user: freshUser)
    }
    sidebarFolders = await foldersTask
    watchlistBadgeCount = await watchlistTask
    sidebarSyncedAt = Date()
    await loadAvatarImage(from: userData?.profile.avatar)
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

  private func loadAvatarImage(from urlString: String?) async {
    guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else {
      avatarImage = nil
      UserProfileCache.shared.clearAvatar()
      return
    }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let image = Self.platformImage(from: data) else { return }
      avatarImage = image
      UserProfileCache.shared.saveAvatar(data)
    } catch {
      // Keep whatever's on screen.
    }
  }

  private static func platformImage(from data: Data) -> Image? {
#if canImport(UIKit)
    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
#elseif canImport(AppKit)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
#endif
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
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
