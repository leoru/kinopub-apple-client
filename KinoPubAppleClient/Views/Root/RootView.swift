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
      MainView(catalog: MediaCatalog(itemsService: appContext.contentService,
                                     authState: authState))
        .tag(NavigationTabs.main)
        .tabItem {
          Label("Main", systemImage: "house")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
      BookmarksView()
        .tag(NavigationTabs.bookmarks)
        .tabItem {
          Label("Bookmarks", systemImage: "bookmark")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
      DownloadsView()
        .tag(NavigationTabs.downloads)
        .tabItem {
          Label("Downloads", systemImage: "arrow.down.circle")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
      SettingsView()
        .tag(NavigationTabs.settings)
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
    }
    .accentColor(Color.KinoPub.accent)
    .task {
      authState.check()
    }
    .sheet(isPresented: $authState.shouldShowAuthentication, content: {
      AuthView(model: AuthModel(authService: appContext.authService, authState: authState))
    })
    .environmentObject(navigationState)
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
