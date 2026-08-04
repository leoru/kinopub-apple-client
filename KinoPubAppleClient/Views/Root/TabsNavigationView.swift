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

/// Primary chrome on iOS, tvOS and macOS — stock system `TabView`.
///
/// Platform IA:
/// - **tvOS:** `.sidebarAdaptable`, profile at the top, Search with `.search` role,
///   Library merges watchlist / history / bookmarks.
/// - **iPhone (compact):** classic `.tabItem` tab bar — the iOS 18+ `Tab` API’s
///   `UIKitTabBarController` asserts on Library selection on Phone.
/// - **iPad (regular):** `Tab` + `.sidebarAdaptable`; Library merges the three personal rows.
/// - **macOS:** sidebar sections (Browse / Library / Folders), profile in
///   `tabViewSidebarBottomBar`, `TabViewCustomization` for show/hide + folders.
struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
#if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  /// Int tags for the classic compact tab bar — avoids `NavigationTabs`’ associated-value
  /// `Hashable` path, which has been implicated in SwiftUI tab identity mismatches.
  @State private var compactTabTag: Int = CompactPhoneTab.home.rawValue
#endif
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  /// Wired at app root. Banner chrome TBD — do not invent community tab-lock UI here.
  @EnvironmentObject var networkMonitor: NetworkMonitor

  /// Sidebar folder tabs — snapshotted so the tab set does not mutate while
  /// Settings is open (same wedge Rivulet guards against on tvOS).
  @State private var sidebarFolders: [Bookmark] = []
  /// Seeded from disk so the profile row is never blank on a cold/offline start;
  /// refreshed from the network, and a failed refresh keeps the cached value.
  @State private var userData: UserData? = UserProfileCache.shared.loadUser()
  /// Rasterized avatar — `AsyncImage` inside a `Tab`/`Label` is stripped by the
  /// system sidebar, which is why the profile row used to show title-only "Settings".
  @State private var avatarImage: Image?
  @State private var watchlistBadgeCount = 0
  @State private var downloadsBadgeCount = 0
  @State private var showSettings = false
  /// Last time the sidebar (folders + watchlist badge) synced with the network.
  /// Without this, every single tab switch fired 2 requests — `syncSidebarFolders()`
  /// used to run unconditionally on every `selectedTab` change.
  @State private var sidebarSyncedAt: Date?
  private static let sidebarSyncTTL: TimeInterval = 120
#if os(macOS)
  @AppStorage("sidebarTabCustomization") private var tabCustomization = TabViewCustomization()
#endif

  var body: some View {
    modernTabs
      .environmentObject(navigationState)
      .environmentObject(errorHandler)
      .task { await loadSidebarChrome() }
      .onChange(of: navigationState.selectedTab) { _, newTab in
#if os(iOS)
        if horizontalSizeClass != .regular, let tag = CompactPhoneTab(newTab)?.rawValue {
          compactTabTag = tag
        }
#endif
        guard !showSettings else { return }
        Task { await syncSidebarFolders() }
      }
      // DESIGN: offline / reachability banner when `networkMonitor.isOnline` flips false.
      .onChange(of: networkMonitor.isOnline) { _, _ in }
  }

  /// Re-selecting the current tab pops that tab's stack to root (Apple Music /
  /// Apple TV). `TabView` still calls the setter with the same value.
  /// Selection must update synchronously — deferring leaves UIKit with a selected
  /// `UITabBarItem` that has no matching VC yet and asserts on Library taps.
  private var tabSelection: Binding<NavigationTabs> {
    Binding(
      get: { navigationState.selectedTab },
      set: { newValue in
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
#if os(tvOS)
    tvSidebarTabs
#elseif os(macOS)
    macSidebarTabs
#else
    phonePadTabs
#endif
  }

  // MARK: - tvOS (flat, profile first, circle icons)

#if os(tvOS)
  @ViewBuilder
  private var tvSidebarTabs: some View {
    if #available(tvOS 27.0, *) {
      tvSidebarTabsWithProfileHeader
    } else {
      tvSidebarTabsWithProfileTab
    }
  }

  /// tvOS 27+: profile row in the sidebar header — avatar, name, days on the trailing edge.
  @available(tvOS 27.0, *)
  @ViewBuilder
  private var tvSidebarTabsWithProfileHeader: some View {
    TabView(selection: tabSelection) {
      tvBrowseTabs
    }
    .tabViewStyle(.sidebarAdaptable)
    .tabViewSidebarHeader {
      Button {
        showSettings = true
      } label: {
        profileHeaderLabel
      }
      .buttonStyle(.plain)
    }
    .fullScreenCover(isPresented: $showSettings) {
      settingsContent
        .environmentObject(navigationState)
        .environmentObject(errorHandler)
        .environmentObject(authState)
    }
  }

  /// tvOS 26: no sidebar header API and no `Tab.badge` — profile is the first tab,
  /// days ride in the title; Library count likewise.
  @ViewBuilder
  private var tvSidebarTabsWithProfileTab: some View {
    TabView(selection: tabSelection) {
      Tab(value: NavigationTabs.settings) {
        settingsContent
      } label: {
        Label {
          Text(profileTabTitle)
        } icon: {
          profileAvatar(size: 36)
        }
      }

      tvBrowseTabs
    }
    .tabViewStyle(.sidebarAdaptable)
  }

  @TabContentBuilder<NavigationTabs>
  private var tvBrowseTabs: some TabContent<NavigationTabs> {
    Tab(value: NavigationTabs.search, role: .search) {
      searchContent
    } label: {
      Label("Search", systemImage: "magnifyingglass")
    }

    Tab(value: NavigationTabs.home) {
      homeContent
    } label: {
      Label("For You", systemImage: "play.fill")
    }

    Tab(value: NavigationTabs.movies) {
      moviesContent
    } label: {
      Label("Movies", systemImage: "movieclapper")
    }

    Tab(value: NavigationTabs.series) {
      seriesContent
    } label: {
      Label("Series", systemImage: "rectangle.stack")
    }

    Tab(value: NavigationTabs.library) {
      libraryContent
    } label: {
      Label(libraryTabTitle, systemImage: "rectangle.stack.fill.badge.person.crop")
    }
  }

  private var profileHeaderLabel: some View {
    HStack(spacing: 12) {
      profileAvatar(size: 36)
      Text(profileDisplayName)
        .lineLimit(1)
      Spacer(minLength: 8)
      if subscriptionDaysBadge > 0 {
        Text("\(subscriptionDaysBadge)")
           .font(.body.monospacedDigit())
           .foregroundStyle(.secondary.opacity(0.5))
//          .font(.subheadline)
      }
    }
    .contentShape(Rectangle())
  }

  /// Name + remaining days when `Tab.badge` / header trailing slot isn't available.
  private var profileTabTitle: String {
    let name = profileDisplayName.trimmingCharacters(in: .whitespaces)
    let display = name.isEmpty ? " " : name
    return subscriptionDaysBadge > 0 ? "\(display)  \(subscriptionDaysBadge)" : display
  }

  private var libraryTabTitle: String {
    let base = "Library".localized
    return libraryBadgeCount > 0 ? "\(base)  \(libraryBadgeCount)" : base
  }

  private func tvTabLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
    Label {
      Text(title)
    } icon: {
      tvTabIcon(systemImage)
    }
  }

  private func tvTabLabel(_ title: String, systemImage: String) -> some View {
    Label {
      Text(title)
    } icon: {
      tvTabIcon(systemImage)
    }
  }

  private func tvTabIcon(_ systemImage: String) -> some View {
    Image(systemName: systemImage)
      .font(.body.weight(.semibold))
      .foregroundStyle(.primary)
      .frame(width: 36, height: 36)
      .background(Circle().fill(Color.secondary.opacity(0.35)))
  }
#endif

  // MARK: - macOS (sections + footer + customization)

#if os(macOS)
  @ViewBuilder
  private var macSidebarTabs: some View {
    TabView(selection: tabSelection) {
      TabSection("Browse") {
        Tab(value: NavigationTabs.search, role: .search) {
          searchContent
        } label: {
          Label("Search", systemImage: "magnifyingglass")
        }
        .customizationID("tab.search")

        Tab("For You", systemImage: "play.fill", value: NavigationTabs.home) {
          homeContent
        }
        .customizationID("tab.home")

        Tab("Movies", systemImage: "movieclapper", value: NavigationTabs.movies) {
          moviesContent
        }
        .customizationID("tab.movies")

        Tab("Series", systemImage: "rectangle.stack", value: NavigationTabs.series) {
          seriesContent
        }
        .customizationID("tab.series")
      }

      TabSection("Library") {
        Tab("Watchlist", systemImage: "text.append", value: NavigationTabs.watchlist) {
          WatchlistView()
        }
        .customizationID("tab.watchlist")
        .badge(watchlistBadgeCount)

        Tab("History", systemImage: "memories", value: NavigationTabs.recentlyWatched) {
          RecentlyWatchedView()
        }
        .customizationID("tab.history")

        Tab("All Bookmarks", systemImage: "bookmark", value: NavigationTabs.bookmarks) {
          savedContent
        }
        .customizationID("tab.bookmarks")
        .badge(bookmarksBadgeCount)

        if FeatureFlags.downloadsEnabled {
          Tab("Downloads", systemImage: "laptopcomputer.and.arrow.down", value: NavigationTabs.downloads) {
            downloadsContent
          }
          .customizationID("tab.downloads")
          .badge(downloadsBadgeCount)
        }
      }

      TabSection("Folders") {
        ForEach(sidebarFolders, id: \.id) { folder in
          Tab(folder.title, systemImage: "folder", value: NavigationTabs.bookmark(folder.id)) {
            BookmarkFolderTabView(bookmark: folder)
          }
          .customizationID("tab.folder.\(folder.id)")
          .badge(Int(folder.count) ?? 0)
        }
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .tabViewCustomization($tabCustomization)
    .tabViewSidebarBottomBar {
      Button {
        showSettings = true
      } label: {
        profileLabel(avatarSize: 20)
      }
      .buttonStyle(.borderless)
      .badge(subscriptionDaysBadge)
    }
    .sheet(isPresented: $showSettings) {
      settingsContent
        .environmentObject(navigationState)
        .environmentObject(errorHandler)
        .environmentObject(authState)
        .frame(minWidth: 480, minHeight: 520)
    }
  }
#endif

  // MARK: - iOS / iPad (Library combined; Downloads own tab)

#if os(iOS)
  @ViewBuilder
  private var phonePadTabs: some View {
    if horizontalSizeClass == .regular {
      phonePadSidebarTabs
    } else {
      phoneCompactTabBar
    }
  }

  /// iPad — new `Tab` API + sidebar. Badges / search role are fine here.
  private var phonePadSidebarTabs: some View {
    TabView(selection: tabSelection) {
      Tab(value: NavigationTabs.search, role: .search) {
        searchContent
      } label: {
        Label("Search", systemImage: "magnifyingglass")
      }

      Tab("For You", systemImage: "play.fill", value: NavigationTabs.home) {
        homeContent
      }

      Tab("Movies", systemImage: "movieclapper", value: NavigationTabs.movies) {
        moviesContent
      }

      Tab("Series", systemImage: "rectangle.stack", value: NavigationTabs.series) {
        seriesContent
      }

      Tab("Library", systemImage: "rectangle.stack.badge.person.crop", value: NavigationTabs.library) {
        libraryContent
      }
      .badge(libraryBadgeCount)

      if FeatureFlags.downloadsEnabled {
        Tab("Downloads", systemImage: "laptopcomputer.and.arrow.down", value: NavigationTabs.downloads) {
          downloadsContent
        }
        .badge(downloadsBadgeCount)
      }

      Tab("Profile", systemImage: "person.crop.circle", value: NavigationTabs.settings) {
        settingsContent
      }
      .badge(subscriptionDaysBadge)
    }
    .tabViewStyle(.sidebarAdaptable)
  }

  /// iPhone — classic `tabItem`/`tag` tab bar. The iOS 18+ `Tab { }` path hosts
  /// `SwiftUI.UIKitTabBarController`, which asserts on Phone when selecting Library
  /// ("No view controller matches the UITabBarItem"). Overflow goes to system More.
  private var phoneCompactTabBar: some View {
    TabView(selection: compactTabSelection) {
      searchContent
        .tabItem { Label("Search", systemImage: "magnifyingglass") }
        .tag(CompactPhoneTab.search.rawValue)

      homeContent
        .tabItem { Label("For You", systemImage: "play.fill") }
        .tag(CompactPhoneTab.home.rawValue)

      moviesContent
        .tabItem { Label("Movies", systemImage: "movieclapper") }
        .tag(CompactPhoneTab.movies.rawValue)

      seriesContent
        .tabItem { Label("Series", systemImage: "rectangle.stack") }
        .tag(CompactPhoneTab.series.rawValue)

      libraryContent
        .tabItem { Label("Library", systemImage: "rectangle.stack.badge.person.crop") }
        .tag(CompactPhoneTab.library.rawValue)

      if FeatureFlags.downloadsEnabled {
        downloadsContent
          .tabItem { Label("Downloads", systemImage: "laptopcomputer.and.arrow.down") }
          .tag(CompactPhoneTab.downloads.rawValue)
      }

      settingsContent
        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        .tag(CompactPhoneTab.settings.rawValue)
    }
  }

  private var compactTabSelection: Binding<Int> {
    Binding(
      get: { compactTabTag },
      set: { newValue in
        if newValue == compactTabTag {
          if let tab = CompactPhoneTab(rawValue: newValue) {
            navigationState.popToRoot(for: tab.navigationTab)
          }
        } else {
          compactTabTag = newValue
          if let tab = CompactPhoneTab(rawValue: newValue) {
            navigationState.selectedTab = tab.navigationTab
          }
        }
      }
    )
  }

  /// Stable Int-backed tabs for the classic iPhone tab bar.
  private enum CompactPhoneTab: Int {
    case search = 0
    case home = 1
    case movies = 2
    case series = 3
    case library = 4
    case downloads = 5
    case settings = 6

    var navigationTab: NavigationTabs {
      switch self {
      case .search: return .search
      case .home: return .home
      case .movies: return .movies
      case .series: return .series
      case .library: return .library
      case .downloads: return .downloads
      case .settings: return .settings
      }
    }

    init?(_ tab: NavigationTabs) {
      switch tab {
      case .search: self = .search
      case .home: self = .home
      case .movies: self = .movies
      case .series: self = .series
      case .library, .watchlist, .recentlyWatched, .bookmarks, .bookmark: self = .library
      case .downloads: self = .downloads
      case .settings: self = .settings
      }
    }
  }
#endif

  // MARK: - Profile chrome

  /// Prefer display name, then username — never "Settings", which made the row
  /// look like a gear-less settings button when the avatar failed to resolve.
  /// With nothing loaded at all (offline cold start, no cache) it's "Profile".
  private var profileDisplayName: String {
    userData?.profile.name?.nilIfEmpty
      ?? userData?.username.nilIfEmpty
      ?? "Profile".localized
  }

  /// Whole days left on the subscription — shown as a trailing sidebar badge.
  private var subscriptionDaysBadge: Int {
    guard let days = userData?.subscription.days else { return 0 }
    return max(0, Int(days.rounded(.down)))
  }

  private var libraryBadgeCount: Int {
    watchlistBadgeCount + bookmarksBadgeCount
  }

  private var bookmarksBadgeCount: Int {
    sidebarFolders.reduce(0) { $0 + (Int($1.count) ?? 0) }
  }

  private func profileLabel(avatarSize: CGFloat) -> some View {
    Label {
      Text(profileDisplayName)
    } icon: {
      profileAvatar(size: avatarSize)
    }
  }

  @ViewBuilder
  private func profileAvatar(size: CGFloat) -> some View {
    if let avatarImage {
      avatarImage
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .clipShape(Circle())
    } else {
      initialsAvatar(size: size)
    }
  }

  private func initialsAvatar(size: CGFloat) -> some View {
    ZStack {
      Circle().fill(Color.secondary.opacity(0.35))
      if profileInitials.isEmpty {
        Image(systemName: "person.fill")
          .font(.system(size: size * 0.45, weight: .semibold))
          .foregroundStyle(Color.primary)
      } else {
        Text(profileInitials)
          .font(.system(size: size * 0.4, weight: .semibold))
          .foregroundStyle(Color.primary)
      }
    }
    .frame(width: size, height: size)
  }

  private var profileInitials: String {
    let name = profileDisplayName.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty else { return "" }
    let parts = name.split(separator: " ").prefix(2)
    let letters = parts.compactMap { $0.first.map(String.init) }
    return letters.isEmpty ? String(name.prefix(1)).uppercased() : letters.joined().uppercased()
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
    CatalogView(title: "Series",
                tab: .series,
                path: \.seriesRoutes,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .serial))
  }

  private var libraryContent: some View {
    LibraryView(catalog: PersonalLibraryCatalog(itemsService: appContext.contentService,
                                                authState: authState,
                                                errorHandler: errorHandler))
  }

  private var savedContent: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
  }

  private var downloadsContent: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager))
  }

  private var settingsContent: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
  }

  // MARK: - Sidebar data

  private func loadSidebarChrome() async {
    if avatarImage == nil, let cachedAvatar = UserProfileCache.shared.loadAvatar() {
      avatarImage = Self.platformImage(from: cachedAvatar)
    }

    async let userTask: UserData? = {
      try? await appContext.userService.fetchUserData()
    }()
    async let foldersTask = fetchFolders()
    async let watchlistTask = fetchWatchlistCount()
#if !os(tvOS)
    let downloads = FeatureFlags.downloadsEnabled
      ? (appContext.downloadedFilesDatabase.readData() ?? []).count
      : 0
#endif

    // A failed fetch must not wipe the cached profile the row is already showing.
    if let freshUser = await userTask {
      userData = freshUser
      UserProfileCache.shared.save(user: freshUser)
    }
    sidebarFolders = await foldersTask
    watchlistBadgeCount = await watchlistTask
#if !os(tvOS)
    downloadsBadgeCount = downloads
#endif
    sidebarSyncedAt = Date()
    await loadAvatarImage(from: userData?.profile.avatar)
  }

  private func syncSidebarFolders() async {
    if let sidebarSyncedAt, Date().timeIntervalSince(sidebarSyncedAt) < Self.sidebarSyncTTL { return }
    async let foldersTask = fetchFolders()
    async let watchlistTask = fetchWatchlistCount()
    let folders = await foldersTask
    let watchlist = await watchlistTask
#if !os(tvOS)
    let downloads = FeatureFlags.downloadsEnabled
      ? (appContext.downloadedFilesDatabase.readData() ?? []).count
      : 0
#endif
    // Only publish when values change — rewriting tab `.badge` during a tab switch
    // recreates `UITabBarItem`s and can assert on iPhone.
    if folders != sidebarFolders { sidebarFolders = folders }
    if watchlist != watchlistBadgeCount { watchlistBadgeCount = watchlist }
#if !os(tvOS)
    if downloads != downloadsBadgeCount { downloadsBadgeCount = downloads }
#endif
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
      // The freshest profile says there is no avatar — drop the cached one too.
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
      // Keep whatever's on screen (possibly the disk-cached copy) — a failed
      // avatar download is not a reason to blank the row.
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

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
      .environmentObject(NetworkMonitor())
  }
}
