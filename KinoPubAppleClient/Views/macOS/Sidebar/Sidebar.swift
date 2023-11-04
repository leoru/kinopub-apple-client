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
      NavigationLink(value: NavigationTabs.main) {
        Label("Main", systemImage: "house")
          .foregroundStyle(Color.white)
      }
      .listRowBackground(selection == .main ? Color.KinoPub.accent : Color.clear)
      .tint(Color.clear)
      
      NavigationLink(value: NavigationTabs.bookmarks) {
        Label("Bookmarks", systemImage: "bookmark")
          .foregroundStyle(Color.white)
      }
      .listRowBackground(selection == .bookmarks ? Color.KinoPub.accent : Color.clear)
      .tint(Color.clear)
      
      NavigationLink(value: NavigationTabs.downloads) {
        Label("Downloads", systemImage: "arrow.down.circle")
          .foregroundStyle(Color.white)
      }
      .listRowBackground(selection == .downloads ? Color.KinoPub.accent : Color.clear)
      .tint(Color.clear)
      
      NavigationLink(value: NavigationTabs.profile) {
        Label("Profile", systemImage: "person.crop.circle")
          .foregroundStyle(Color.white)
      }
      .listRowBackground(selection == .profile ? Color.KinoPub.accent : Color.clear)
      .tint(Color.clear)
    }
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
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

#endif
