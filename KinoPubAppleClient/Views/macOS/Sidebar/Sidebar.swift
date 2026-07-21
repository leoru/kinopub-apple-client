//
//  Sidebar.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI

#if os(macOS)
struct Sidebar: View {
  
  @Binding var selection: NavigationTabs
  
  var body: some View {
    List(selection: $selection) {
      row(.search, title: "Search", icon: "magnifyingglass")
      row(.home, title: "Home", icon: "house")
      row(.movies, title: "Movies", icon: "film")
      row(.series, title: "Series", icon: "tv")
      row(.saved, title: "Saved", icon: "bookmark")
      row(.downloads, title: "Downloads", icon: "arrow.down.circle")
      row(.settings, title: "Settings", icon: "gear")
    }
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
    .navigationTitle("Home")
#if os(macOS)
    .navigationSplitViewColumnWidth(min: 200, ideal: 200)
#endif
  }

  private func row(_ tab: NavigationTabs, title: LocalizedStringKey, icon: String) -> some View {
    NavigationLink(value: tab) {
      Label(title, systemImage: icon)
        .foregroundStyle(Color.white)
    }
    .listRowBackground(selection == tab ? Color.KinoPub.accent : Color.clear)
    .tint(Color.clear)
  }
}

struct Sidebar_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: NavigationTabs = NavigationTabs.home
    var body: some View {
      Sidebar(selection: $selection)
    }
  }
  
  static var previews: some View {
    NavigationSplitView {
      Preview()
    } detail: {
      Text("Detail!")
    }
  }
}

#endif
