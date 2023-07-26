//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import KinoPubUI

struct RootView: View {
  
  @State var showAuth: Bool = false
  @Environment(\.appContext) var appContext
  
  var body: some View {
    TabView {
      MainView(catalog: MediaCatalog(itemsService: appContext.contentService))
        .tabItem {
          Label("Main", systemImage: "house")
        }
        .toolbarBackground(Color.KinoPub.background, for: .tabBar)
      BookmarksView()
        .tabItem {
          Label("Bookmarks", systemImage: "bookmark")
        }
        .toolbarBackground(Color.KinoPub.background, for: .tabBar)
      DownloadsView()
        .tabItem {
          Label("Downloads", systemImage: "arrow.down.circle")
        }
        .toolbarBackground(Color.KinoPub.background, for: .tabBar)
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
        .toolbarBackground(Color.KinoPub.background, for: .tabBar)
    }
    .accentColor(Color.KinoPub.accent)
    .onAppear(perform: {
      showAuth = false
    })
    .sheet(isPresented: $showAuth, content: {
      AuthView()
    })
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
