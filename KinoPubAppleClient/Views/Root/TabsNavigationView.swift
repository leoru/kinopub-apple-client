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
#if os(iOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }
  
  var body: some View {
    TabView {
      mainTab
      bookmarksTab
      downloadsTab
      profileTab
    }
    .accentColor(Color.KinoPub.accent)
    .sheet(isPresented: $authState.shouldShowAuthentication, content: {
      AuthView(model: AuthModel(authService: appContext.authService,
                                authState: authState,
                                errorHandler: errorHandler))
    })
    .environmentObject(navigationState)
    .environmentObject(errorHandler)
    .task {
      authState.check()
    }
  }
  
  var mainTab: some View {
    MainView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                   authState: authState,
                                   errorHandler: errorHandler))
    .tag(NavigationTabs.main)
    .tabItem {
      Label("Main", systemImage: "house")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var bookmarksTab: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: appContext.contentService,
                                            authState: authState,
                                            errorHandler: errorHandler))
    .tag(NavigationTabs.bookmarks)
    .tabItem {
      Label("Bookmarks", systemImage: "bookmark")
    }
    .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var downloadsTab: some View {
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: appContext.downloadedFilesDatabase, downloadManager: appContext.downloadManager))
      .tag(NavigationTabs.downloads)
      .tabItem {
        Label("Downloads", systemImage: "arrow.down.circle")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
  
  var profileTab: some View {
    ProfileView(model: ProfileModel(userService: appContext.userService,
                                    errorHandler: errorHandler,
                                    authState: authState))
      .tag(NavigationTabs.profile)
      .tabItem {
        Label("Profile", systemImage: "person.crop.circle")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
}

struct TabsNavigationView_Previews: PreviewProvider {
  static var previews: some View {
    TabsNavigationView()
  }
}
