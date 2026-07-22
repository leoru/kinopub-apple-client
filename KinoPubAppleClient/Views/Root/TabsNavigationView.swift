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

struct TabsNavigationView: View {

  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState

  var placement: ToolbarPlacement {
#if os(iOS) || os(tvOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }

  /// tvOS tab bars are text, so labelled tabs drop their icon there. Search and
  /// Settings are the exception: they are icons alone, as on Apple TV.
  @ViewBuilder
  private func tabLabel(_ title: LocalizedStringKey, systemImage: String, iconOnly: Bool = false) -> some View {
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

  var body: some View {
    // Bound, or TabView opens on the first tab — Search sits leftmost, but Home is
    // where the app should land.
    TabView(selection: $navigationState.selectedTab) {
      searchTab
      homeTab
      moviesTab
      seriesTab
      savedTab
#if !os(tvOS)
      downloadsTab
#endif
      settingsTab
    }
    .accentColor(Color.KinoPub.accent)
    .environmentObject(navigationState)
    .environmentObject(errorHandler)
  }

  var searchTab: some View {
    SearchView(catalog: LibraryCatalog(itemsService: appContext.contentService,
                                     authState: authState,
                                     errorHandler: errorHandler))
    .tag(NavigationTabs.search)
    .tabItem {
      tabLabel("Search", systemImage: "magnifyingglass", iconOnly: true)
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var homeTab: some View {
    MainView(catalog: HomeCatalog(itemsService: appContext.contentService,
                                  authState: authState,
                                  errorHandler: errorHandler))
    .tag(NavigationTabs.home)
    .tabItem {
      tabLabel("Home", systemImage: "house")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var moviesTab: some View {
    CatalogView(title: "Movies",
                path: \.moviesRoutes,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .movie))
    .tag(NavigationTabs.movies)
    .tabItem {
      tabLabel("Movies", systemImage: "film")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var seriesTab: some View {
    CatalogView(title: "Series",
                path: \.seriesRoutes,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .serial))
    .tag(NavigationTabs.series)
    .tabItem {
      tabLabel("Series", systemImage: "tv")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var savedTab: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
    .tag(NavigationTabs.saved)
    .tabItem {
      tabLabel("Saved", systemImage: "bookmark")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var downloadsTab: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager))
      .tag(NavigationTabs.downloads)
      .tabItem {
        tabLabel("Downloads", systemImage: "arrow.down.circle")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }

  var settingsTab: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
      .tag(NavigationTabs.settings)
      .tabItem {
        tabLabel("Settings", systemImage: "gear", iconOnly: true)
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
}

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
  }
}
