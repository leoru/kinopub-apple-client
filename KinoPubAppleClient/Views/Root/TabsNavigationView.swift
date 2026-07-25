//
//  TabsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Primary chrome on iOS, tvOS and macOS — stock system `TabView` with
/// `.sidebarAdaptable` (sidebar on Mac/TV, tab bar on iPhone, adaptable on iPad).
///
/// Music-style IA, platform APIs as they actually ship (see Apple’s Tab navigation
/// guide + Rivulet’s `TVSidebarView`):
/// - `defaultVisibility(_:for:)` — iOS/macOS/visionOS only (unavailable on tvOS)
/// - `tabViewSidebarFooter` — iOS 18 / macOS 15 / **tvOS 27+**; on older tvOS the
///   profile sits in a trailing `TabSection("")` like Rivulet’s Settings row
struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState

  /// Sidebar folder tabs — snapshotted so the tab set does not mutate while
  /// Settings is open (same wedge Rivulet guards against on tvOS).
  @State private var sidebarFolders: [Bookmark] = []
  @State private var userData: UserData?
  @State private var showSettings = false

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
    // Single-parameter form: still required for the iOS 16 deployment target.
    .onChange(of: navigationState.selectedTab) { _ in
      guard !showSettings else { return }
      Task { await syncSidebarFolders() }
    }
  }

  // MARK: - tvOS (Rivulet-shaped: no defaultVisibility, no footer API until 27)

#if os(tvOS)
  @available(tvOS 18.0, *)
  @ViewBuilder
  private var tvSidebarTabs: some View {
    TabView(selection: $navigationState.selectedTab) {
        TabSection("") {
          Tab(value: NavigationTabs.settings) {
            settingsContent
          } label: {
            Label {
              Text(footerName)
            } icon: {
              profileAvatar
            }
          }
        }
      browseTabs
      personalTabs
      bookmarksTabs
      // Profile / Settings as a trailing section — Rivulet does the same until
      // tabViewSidebarFooter exists on the OS we ship against.
    }
    .tabViewStyle(.sidebarAdaptable)
  }
#endif

  // MARK: - iOS / macOS (tab-bar visibility + sidebar footer)

#if !os(tvOS)
  @available(iOS 18.0, macOS 15.0, *)
  @ViewBuilder
  private var adaptableSidebarTabs: some View {
    TabView(selection: $navigationState.selectedTab) {
      browseTabs
      personalTabs
        .defaultVisibility(.hidden, for: .tabBar)
      bookmarksTabs
        .defaultVisibility(.hidden, for: .tabBar)
    }
    .tabViewStyle(.sidebarAdaptable)
    .tabViewSidebarFooter {
      Button {
        showSettings = true
      } label: {
        Label {
          Text(footerName)
        } icon: {
          profileAvatar
        }
      }
      .buttonStyle(.plain)
    }
    .sheet(isPresented: $showSettings) {
      settingsContent
        .environmentObject(navigationState)
        .environmentObject(errorHandler)
        .environmentObject(authState)
#if os(macOS)
        .frame(minWidth: 480, minHeight: 520)
#endif

    }
  }
#endif

  /// Bound selection so we land on For You (home), not the leftmost Search tab.
  @available(iOS 18.0, tvOS 18.0, macOS 15.0, *)
  @ViewBuilder
  private var modernTabs: some View {
#if os(tvOS)
      tvSidebarTabs
#else
    adaptableSidebarTabs
#endif
  }

  // MARK: - Shared tab groups (TabContent, used inside TabView)

  @available(iOS 18.0, tvOS 18.0, macOS 15.0, *)
  @TabContentBuilder<NavigationTabs>
  private var browseTabs: some TabContent<NavigationTabs> {
    Tab("Search", systemImage: "magnifyingglass", value: NavigationTabs.search) {
      searchContent
    }

    Tab("For You", systemImage: "play.fill", value: NavigationTabs.home) {
      homeContent
    }

//    Tab("Movies", systemImage: "movieclapper", value: NavigationTabs.movies) {
//      moviesContent
//    }
//
//    Tab("Series", systemImage: "rectangle.stack", value: NavigationTabs.series) {
//      seriesContent
//    }
  }

  @available(iOS 18.0, tvOS 18.0, macOS 15.0, *)
  @TabContentBuilder<NavigationTabs>
  private var personalTabs: some TabContent<NavigationTabs> {
    TabSection("Library") {
      Tab("Watchlist", systemImage: "text.append", value: NavigationTabs.watchlist) {
        WatchlistView()
      }
        Tab("History", systemImage: "memories", value: NavigationTabs.recentlyWatched) {


//      Tab("Recently Watched", systemImage: "memories", value: NavigationTabs.recentlyWatched) {
        RecentlyWatchedView()
      }

      Tab("Downloads", systemImage: "laptopcomputer.and.arrow.down", value: NavigationTabs.downloads) {
        downloadsContent
      }

    }
  }
      

  @available(iOS 18.0, tvOS 18.0, macOS 15.0, *)
  @TabContentBuilder<NavigationTabs>
  private var bookmarksTabs: some TabContent<NavigationTabs> {
    TabSection("Folders") {
      Tab("All Bookmarks", systemImage: "bookmark", value: NavigationTabs.bookmarks) {
        savedContent
      }

      ForEach(sidebarFolders, id: \.id) { folder in
        Tab(folder.title, systemImage: "folder", value: NavigationTabs.bookmark(folder.id)) {
          BookmarkFolderTabView(bookmark: folder)
        }
      }
    }
  }

  // MARK: - Profile chrome

  private var footerName: String {
    userData?.profile.name?.nilIfEmpty
      ?? userData?.username
      ?? "Settings".localized
  }

  @ViewBuilder
  private var profileAvatar: some View {
    let url = URL(string: userData?.profile.avatar ?? "")
    if let url, !url.absoluteString.isEmpty {
      AsyncImage(url: url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          initialsAvatar
        }
      }
      .frame(width: 20, height: 20)
      .clipShape(Circle())
    } else {
      initialsAvatar
    }
  }

  private var initialsAvatar: some View {
    ZStack {
      Circle().fill(Color.secondary.opacity(0.35))
      Text(footerInitials)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.primary)
    }
    .frame(width: 20, height: 20)
  }

  private var footerInitials: String {
    let name = footerName
    let parts = name.split(separator: " ").prefix(2)
    let letters = parts.compactMap { $0.first.map(String.init) }
    return letters.isEmpty ? String(name.prefix(1)).uppercased() : letters.joined().uppercased()
  }

  // MARK: - Legacy TabView (pre–Tab API)

  private var legacyTabs: some View {
    TabView(selection: $navigationState.selectedTab) {
      searchContent
        .tag(NavigationTabs.search)
        .tabItem { legacyLabel("Search", systemImage: "magnifyingglass", iconOnly: true) }

      homeContent
        .tag(NavigationTabs.home)
//        .tabItem { legacyLabel("For You", systemImage: "popcorn") }
        .tabItem { legacyLabel("For You", systemImage: "play.fill")}
//      moviesContent
//        .tag(NavigationTabs.movies)
//        .tabItem { legacyLabel("Movies", systemImage: "movieclapper") }

//      seriesContent
//        .tag(NavigationTabs.series)
//        .tabItem { legacyLabel("Series", systemImage: "rectangle.stack") }

      WatchlistView()
        .tag(NavigationTabs.watchlist)
//        .tabItem { legacyLabel("Watchlist", systemImage: "tv") }
        .tabItem { legacyLabel("Watchlist", systemImage: "text.append") }

        
      RecentlyWatchedView()
        .tag(NavigationTabs.recentlyWatched)
//        .tabItem { legacyLabel("Recently Watched", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") }
        .tabItem { legacyLabel("History", systemImage: "memories") }

      savedContent
        .tag(NavigationTabs.bookmarks)
        .tabItem { legacyLabel("All Bookmarks", systemImage: "bookmark") }

      downloadsContent
        .tag(NavigationTabs.downloads)
        .tabItem { legacyLabel("Downloads", systemImage: "laptopcomputer.and.arrow.down") }

      settingsContent
        .tag(NavigationTabs.settings)
        .tabItem { legacyLabel("Settings", systemImage: "gear") }
    }
  }

  /// tvOS tab bars are text, so labelled tabs drop their icon there. Search and
  /// Settings are the exception: they are icons alone, as on Apple TV.
  @ViewBuilder
  private func legacyLabel(_ title: LocalizedStringKey, systemImage: String, iconOnly: Bool = false) -> some View {
#if os(tvOS)
      
      Label(title, systemImage: systemImage)

#else
    Label(title, systemImage: systemImage)
#endif
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
    userData = await userTask
    sidebarFolders = await foldersTask
  }

  private func syncSidebarFolders() async {
    sidebarFolders = await fetchFolders()
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
  /*.EnvironmentObject(navigationState(mainRoutes))*/
}
