//
//  RootView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI

struct RootView: View {
  var body: some View {
    TabView {
      MainView()
        .tabItem {
          Label("Главная", systemImage: "house")
        }
      BookmarksView()
        .tabItem {
          Label("Закладки", systemImage: "house")
        }
      DownloadsView()
        .tabItem {
          Label("Загрузки", systemImage: "house")
        }
      SettingsView()
        .tabItem {
          Label("Настройки", systemImage: "house")
        }
    }
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
