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

/// Primary chrome on iOS, tvOS and macOS.
///
/// `.tabViewStyle(.sidebarAdaptable)` is the system sidebar on macOS (and tvOS 18+) —
/// Liquid Glass / floating over content on current SDKs. Grow it further with
/// `TabSection`, search role, bottom-pinned profile, etc.:
/// - Search: inline search field in the sidebar; focus jumps into the page
/// - Saved: watchlist + all my lists, with a + button
/// - Settings: profile affordance pinned at the bottom, not a middle row
struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState

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
  }

  /// Bound selection so we land on Home, not the leftmost Search tab.
  @available(iOS 18.0, tvOS 18.0, macOS 15.0, *)
  private var modernTabs: some View {
    TabView(selection: $navigationState.selectedTab) {
      Tab(value: NavigationTabs.search, role: .search) {
        page(searchContent)
      }

      Tab("Home", systemImage: "square.grid.2x2", value: NavigationTabs.home) {
        page(homeContent)
      }

      Tab("Movies", systemImage: "film", value: NavigationTabs.movies) {
        page(moviesContent)
      }

      Tab("Series", systemImage: "tv", value: NavigationTabs.series) {
        page(seriesContent)
      }

      Tab("My Library", systemImage: "bookmark", value: NavigationTabs.saved) {
        page(savedContent)
      }

#if !os(tvOS)
      Tab("Downloads", systemImage: "arrow.down", value: NavigationTabs.downloads) {
        page(downloadsContent)
      }
#endif

      Tab(value: NavigationTabs.settings) {
        page(settingsContent)
      } label: {
#if os(tvOS)
        Image(systemName: "gear")
#else
        Label("Settings", systemImage: "gear")
#endif
      }
    }
    .tabViewStyle(.sidebarAdaptable)
#if os(macOS)
    // Apple TV–style: soft grey selection pill, not the system accent-blue fill.
    .tint(Color(nsColor: .tertiaryLabelColor))
#endif
  }

  /// Sidebar tint stays on the chrome; page controls keep the system accent.
  @ViewBuilder
  private func page<Content: View>(_ content: Content) -> some View {
#if os(macOS)
    content.tint(Color(nsColor: .controlAccentColor))
#else
    content
#endif
  }

  private var legacyTabs: some View {
    TabView(selection: $navigationState.selectedTab) {
      searchContent
        .tag(NavigationTabs.search)
        .tabItem { legacyLabel("Search", systemImage: "magnifyingglass", iconOnly: true) }

      homeContent
        .tag(NavigationTabs.home)
        .tabItem { legacyLabel("Home", systemImage: "square.grid.2x2") }

      moviesContent
        .tag(NavigationTabs.movies)
        .tabItem { legacyLabel("Movies", systemImage: "film") }

      seriesContent
        .tag(NavigationTabs.series)
        .tabItem { legacyLabel("Series", systemImage: "tv") }

      savedContent
        .tag(NavigationTabs.saved)
        .tabItem { legacyLabel("My Library", systemImage: "bookmark") }

#if !os(tvOS)
      downloadsContent
        .tag(NavigationTabs.downloads)
        .tabItem { legacyLabel("Downloads", systemImage: "arrow.down") }
#endif

      settingsContent
        .tag(NavigationTabs.settings)
        .tabItem { legacyLabel("Settings", systemImage: "gear", iconOnly: true) }
    }
  }

  /// tvOS tab bars are text, so labelled tabs drop their icon there. Search and
  /// Settings are the exception: they are icons alone, as on Apple TV.
  @ViewBuilder
  private func legacyLabel(_ title: LocalizedStringKey, systemImage: String, iconOnly: Bool = false) -> some View {
#if os(tvOS)
    if iconOnly {
      Image(systemName: systemImage)
    } else {
      Text(title)
    }
#else
    Label(title, systemImage: systemImage)
#endif
  }

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
}

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
  }
}
