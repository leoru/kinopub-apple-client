//
//  Sidebar.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI

struct Sidebar: View {
  
  @Binding var selection: NavigationTabs
  
  var body: some View {
    List(selection: $selection) {
      NavigationLink(value: NavigationTabs.main) {
        Label("Main", systemImage: "house")
      }
      NavigationLink(value: NavigationTabs.bookmarks) {
        Label("Bookmarks", systemImage: "bookmark")
      }
      NavigationLink(value: NavigationTabs.downloads) {
        Label("Downloads", systemImage: "arrow.down.circle")
      }
      NavigationLink(value: NavigationTabs.profile) {
        Label("Profile", systemImage: "person.crop.circle")
      }
    }
    .navigationTitle("Main")
#if os(macOS)
    .navigationSplitViewColumnWidth(min: 200, ideal: 200)
#endif
  }
}

struct Sidebar_Previews: PreviewProvider {
  struct Preview: View {
    @State private var selection: NavigationTabs = NavigationTabs.main
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
