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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Primary chrome on iOS, tvOS and macOS — stock system `TabView` with
/// `.sidebarAdaptable` (sidebar on Mac/TV, tab bar on iPhone, adaptable on iPad).
///
/// Platform IA:
/// - **tvOS:** flat tabs (no `TabSection`), profile at the top, Search next,
///   Library merges watchlist / history / bookmarks; circular icon underlays.
/// - **iOS / iPad:** Library likewise merges those three; Downloads stays its own tab.
/// - **macOS:** sidebar sections (Browse / Library / Folders), profile in
///   `tabViewSidebarFooter`, `TabViewCustomization` for show/hide + folders.
struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState

  /// Sidebar folder tabs — snapshotted so the tab set does not mutate while
  /// Settings is open (same wedge Rivulet guards against on tvOS).
  @State private var sidebarFolders: [Bookmark] = []
  @State private var userData: UserData?
  /// Rasterized avatar — `AsyncImage` inside a `Tab`/`Label` is stripped by the
  /// system sidebar, which is why the profile row used to show title-only "Settings".
  @State private var avatarImage: Image?
  @State private var watchlistBadgeCount = 0
  @State private var downloadsBadgeCount = 0
  @State private var showSettings = false
#if os(macOS)
  @AppStorage("sidebarTabCustomization") private var tabCustomization = TabViewCustomization()
#endif

  var body: some View {
    Group {
      if #available(iOS 18.0, tvOS 18.0, macOS 15.0, *) {
        modernTabs
      } else {
        legacyTabs
      }
    }
    .environmentObject(navigationState)
    .environmentObject(errorHandler)
    .task { await loadSidebarChrome() }
    .onChange(of: navigationState.selectedTab) { _ in
      guard !showSettings else { return }
      Task { await syncSidebarFolders() }
    }
  }

  /// Re-selecting the current tab pops that tab's stack to root (Apple Music /
  /// Apple TV). `TabView` still calls the setter with the same value.
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

  // MARK: - Modern TabView

  @available(iOS 18.0, tvOS 18.0, macOS 15.0, *)
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
  @available(tvOS 18.0, *)
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

  /// tvOS 18–26: no sidebar header API and no `Tab.badge` — profile is the first tab,
  /// days ride in the title; Library count likewise.
  @available(tvOS 18.0, *)
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

  @available(tvOS 18.0, *)
  @TabContentBuilder<NavigationTabs>
  private var tvBrowseTabs: some TabContent<NavigationTabs> {
    Tab(value: NavigationTabs.search) {
      searchContent
    } label: {
      tvTabLabel("Search", systemImage: "magnifyingglass")
    }

    Tab(value: NavigationTabs.home) {
      homeContent
    } label: {
      tvTabLabel("For You", systemImage: "play.fill")
    }

    Tab(value: NavigationTabs.movies) {
      moviesContent
    } label: {
      tvTabLabel("Movies", systemImage: "movieclapper")
    }

    Tab(value: NavigationTabs.series) {
      seriesContent
    } label: {
      tvTabLabel("Series", systemImage: "rectangle.stack")
    }

    Tab(value: NavigationTabs.library) {
      libraryContent
    } label: {
      tvTabLabel(libraryTabTitle, systemImage: "rectangle.stack.fill.badge.person.crop")
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
  @available(macOS 15.0, *)
  @ViewBuilder
  private var macSidebarTabs: some View {
    TabView(selection: tabSelection) {
      TabSection("Browse") {
        Tab("Search", systemImage: "magnifyingglass", value: NavigationTabs.search) {
          searchContent
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

        Tab("Downloads", systemImage: "laptopcomputer.and.arrow.down", value: NavigationTabs.downloads) {
          downloadsContent
        }
        .customizationID("tab.downloads")
        .badge(downloadsBadgeCount)
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
    .tabViewSidebarFooter {
      Button {
        showSettings = true
      } label: {
        profileLabel(avatarSize: 20)
      }
      .buttonStyle(.plain)
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
  @available(iOS 18.0, *)
  @ViewBuilder
  private var phonePadTabs: some View {
    TabView(selection: tabSelection) {
      Tab("Search", systemImage: "magnifyingglass", value: NavigationTabs.search) {
        searchContent
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

      Tab("Library", systemImage: "rectangle.stack.fill.badge.person.crop", value: NavigationTabs.library) {
        libraryContent
      }
      .badge(libraryBadgeCount)

      Tab("Downloads", systemImage: "laptopcomputer.and.arrow.down", value: NavigationTabs.downloads) {
        downloadsContent
      }
      .defaultVisibility(.hidden, for: .tabBar)
      .badge(downloadsBadgeCount)

      Tab(value: NavigationTabs.settings) {
        settingsContent
      } label: {
        profileLabel(avatarSize: 20)
      }
      .defaultVisibility(.hidden, for: .tabBar)
      .badge(subscriptionDaysBadge)
    }
    .tabViewStyle(.sidebarAdaptable)
  }
#endif

  // MARK: - Profile chrome

  /// Prefer display name, then username — never "Settings", which made the row
  /// look like a gear-less settings button when the avatar failed to resolve.
  private var profileDisplayName: String {
    userData?.profile.name?.nilIfEmpty
      ?? userData?.username.nilIfEmpty
      ?? " "
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

  // MARK: - Legacy TabView (pre–Tab API)

  private var legacyTabs: some View {
    TabView(selection: tabSelection) {
      searchContent
        .tag(NavigationTabs.search)
        .tabItem { Label("Search", systemImage: "magnifyingglass") }

      homeContent
        .tag(NavigationTabs.home)
        .tabItem { Label("For You", systemImage: "play.fill") }

      moviesContent
        .tag(NavigationTabs.movies)
        .tabItem { Label("Movies", systemImage: "movieclapper") }

      seriesContent
        .tag(NavigationTabs.series)
        .tabItem { Label("Series", systemImage: "rectangle.stack") }

#if os(macOS)
      WatchlistView()
        .tag(NavigationTabs.watchlist)
        .tabItem { Label("Watchlist", systemImage: "text.append") }

      RecentlyWatchedView()
        .tag(NavigationTabs.recentlyWatched)
        .tabItem { Label("History", systemImage: "memories") }

      savedContent
        .tag(NavigationTabs.bookmarks)
        .tabItem { Label("All Bookmarks", systemImage: "bookmark") }
#else
      libraryContent
        .tag(NavigationTabs.library)
        .tabItem { Label("Library", systemImage: "rectangle.stack.fill.badge.person.crop") }
#endif

#if !os(tvOS)
      downloadsContent
        .tag(NavigationTabs.downloads)
        .tabItem { Label("Downloads", systemImage: "laptopcomputer.and.arrow.down") }
#endif

      settingsContent
        .tag(NavigationTabs.settings)
        .tabItem { Label("Settings", systemImage: "gear") }
    }
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
    async let userTask: UserData? = {
      try? await appContext.userService.fetchUserData()
    }()
    async let foldersTask = fetchFolders()
    async let watchlistTask = fetchWatchlistCount()
#if !os(tvOS)
    let downloads = (appContext.downloadedFilesDatabase.readData() ?? []).count
#endif

    userData = await userTask
    sidebarFolders = await foldersTask
    watchlistBadgeCount = await watchlistTask
#if !os(tvOS)
    downloadsBadgeCount = downloads
#endif
    await loadAvatarImage(from: userData?.profile.avatar)
  }

  private func syncSidebarFolders() async {
    async let foldersTask = fetchFolders()
    async let watchlistTask = fetchWatchlistCount()
    sidebarFolders = await foldersTask
    watchlistBadgeCount = await watchlistTask
#if !os(tvOS)
    downloadsBadgeCount = (appContext.downloadedFilesDatabase.readData() ?? []).count
#endif
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
      return
    }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
#if canImport(UIKit)
      guard let uiImage = UIImage(data: data) else {
        avatarImage = nil
        return
      }
      avatarImage = Image(uiImage: uiImage)
#elseif canImport(AppKit)
      guard let nsImage = NSImage(data: data) else {
        avatarImage = nil
        return
      }
      avatarImage = Image(nsImage: nsImage)
#endif
    } catch {
      avatarImage = nil
    }
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
  }
}
