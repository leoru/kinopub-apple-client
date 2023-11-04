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
    case .main:
      main
    case .bookmarks:
      bookmarks
    case .downloads:
      downloads
    case .profile:
      profile
    }
  }
  
  var main: some View {
    MainView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                   authState: authState,
                                   errorHandler: errorHandler))
  }
  
  var bookmarks: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
  }
  
  var downloads: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager))
  }
  
  var profile: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
  }
}

struct SidebarNavigationDetail_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: NavigationTabs = .main
    var body: some View {
      SidebarNavigationDetail(selection: $selection)
    }
  }
  static var previews: some View {
    Preview()
  }
}

#endif
