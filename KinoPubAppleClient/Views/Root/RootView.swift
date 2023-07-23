//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI

struct RootView: View {
  
  @State var showAuth: Bool = false
  
  var body: some View {
    TabView {
      MainView()
        .tabItem {
          Label("Main", systemImage: "house")
        }
      BookmarksView()
        .tabItem {
          Label("Bookmarks", systemImage: "bookmark")
        }
      DownloadsView()
        .tabItem {
          Label("Downloads", systemImage: "arrow.down.circle")
        }
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
    }
    .onAppear(perform: {
      showAuth = true
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
