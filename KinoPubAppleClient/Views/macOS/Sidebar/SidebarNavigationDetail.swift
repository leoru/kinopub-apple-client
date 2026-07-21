//
//  SidebarNavigationDetail.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI

#if os(macOS)
struct SidebarNavigationDetail: View {
  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  
  @Binding var selection: NavigationTabs
  
  var body: some View {
    switch selection {
    case .search:
      search
    case .home:
      home
    case .movies:
      movies
    case .series:
      series
    case .saved:
      saved
    case .downloads:
      downloads
    case .settings:
      settings
    }
  }
  
  var home: some View {
    MainView(catalog: HomeCatalog(itemsService: appContext.contentService,
                                  authState: authState,
                                  errorHandler: errorHandler))
  }
  
  var search: some View {
    SearchView(catalog: LibraryCatalog(itemsService: appContext.contentService,
                                     authState: authState,
                                     errorHandler: errorHandler))
  }

  var movies: some View {
    CatalogView(title: "Movies",
                path: \.moviesRoutes,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .movie))
  }

  var series: some View {
    CatalogView(title: "Series",
                path: \.seriesRoutes,
                catalog: MediaCatalog(itemsService: appContext.contentService,
                                      authState: authState,
                                      errorHandler: errorHandler,
                                      contentType: .serial))
  }

  var saved: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
  }
  
  var downloads: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager))
  }
  
  var settings: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
  }
}

struct SidebarNavigationDetail_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: NavigationTabs = .home
    var body: some View {
      SidebarNavigationDetail(selection: $selection)
    }
  }
  static var previews: some View {
    Preview()
  }
}

#endif
