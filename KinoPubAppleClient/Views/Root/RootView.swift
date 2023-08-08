//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct RootView: View {
  
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
      settingsTab
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
  
  var settingsTab: some View {
    SettingsView()
      .tag(NavigationTabs.settings)
      .tabItem {
        Label("Settings", systemImage: "gearshape")
      }
      .toolbarBackground(Color.KinoPub.background, for: placement)
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
