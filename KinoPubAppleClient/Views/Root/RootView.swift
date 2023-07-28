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
  
  @State var showAuth: Bool = false
  @Environment(\.appContext) var appContext
  
  var placement: ToolbarPlacement {
#if os(iOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }
  
  private func refreshToken() {
    guard let _ : AccessToken = appContext.accessTokenService.token() else {
      showAuth = true
      return
    }
    //    Task {
    //      do {
    //        try await appContext.authService.refreshToken()
    //      } catch {
    //        await MainActor.run {
    //          showAuth = true
    //        }
    //      }
    //    }
  }
  
  var body: some View {
    TabView {
      MainView()
        .tabItem {
          Label("Main", systemImage: "house")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
      BookmarksView()
        .tabItem {
          Label("Bookmarks", systemImage: "bookmark")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
      DownloadsView()
        .tabItem {
          Label("Downloads", systemImage: "arrow.down.circle")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
        .toolbarBackground(Color.KinoPub.background, for: placement)
    }
    .accentColor(Color.KinoPub.accent)
    .task {
      refreshToken()
    }
    .sheet(isPresented: $showAuth, content: {
      AuthView()
        .environmentObject(AuthModel(authService: appContext.authService))
    })
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
