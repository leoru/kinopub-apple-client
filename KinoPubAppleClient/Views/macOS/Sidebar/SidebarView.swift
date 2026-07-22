//
//  SidebarView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend

#if os(macOS)
struct SidebarView: View {
  
  @Environment(\.appContext) var appContext
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  
  var body: some View {
    NavigationSplitView(columnVisibility: $navigationState.columnVisibility) {
      Sidebar(selection: $navigationState.selectedTab)
    } detail: {
      SidebarNavigationDetail(selection: $navigationState.selectedTab)
    }
    .accentColor(Color.KinoPub.accent)
    .environmentObject(navigationState)
    .environmentObject(errorHandler)
  }

}

struct SideBarView_Previews: PreviewProvider {
  static var previews: some View {
    SidebarView()
  }
}

#endif
