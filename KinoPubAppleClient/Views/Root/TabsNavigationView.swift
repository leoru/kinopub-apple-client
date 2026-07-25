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
/// Modelled on Rivulet's `TVSidebarView`: modern `Tab` / `TabSection` API, no
/// custom tint. Grow further without leaving TabView:
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
      Tab("Search", systemImage: "magnifyingglass", value: NavigationTabs.search) {
        searchContent
      }

      Tab("Home", systemImage: "house.fill", value: NavigationTabs.home) {
        homeContent
      }

      TabSection("Library") {
        Tab("Movies", systemImage: "film", value: NavigationTabs.movies) {
          moviesContent
        }

        Tab("Series", systemImage: "tv", value: NavigationTabs.series) {
          seriesContent
        }
      }

      Tab("My Library", systemImage: "bookmark", value: NavigationTabs.saved) {
        savedContent
      }

#if !os(tvOS)
      Tab("Downloads", systemImage: "arrow.down", value: NavigationTabs.downloads) {
        downloadsContent
      }
#endif

      // Trailing section — Settings (and later a bottom-pinned profile) sits apart
      // from the browse tabs, matching Rivulet / Apple TV.
      TabSection("") {
        Tab("Settings", systemImage: "gearshape.fill", value: NavigationTabs.settings) {
          settingsContent
        }
      }
    }
    .tabViewStyle(.sidebarAdaptable)
  }

  private var legacyTabs: some View {
    TabView(selection: $navigationState.selectedTab) {
      searchContent
        .tag(NavigationTabs.search)
        .tabItem { legacyLabel("Search", systemImage: "magnifyingglass", iconOnly: true) }

      homeContent
        .tag(NavigationTabs.home)
        .tabItem { legacyLabel("Home", systemImage: "house.fill") }

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
        .tabItem { legacyLabel("Settings", systemImage: "gearshape.fill", iconOnly: true) }
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
