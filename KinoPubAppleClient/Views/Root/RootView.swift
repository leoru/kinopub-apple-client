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
  
  var placement: ToolbarPlacement {
#if os(iOS)
    .tabBar
#elseif os(macOS)
    .windowToolbar
#endif
  }
  
  var body: some View {
#if os(iOS)
    TabsNavigationView()
#elseif os(macOS)
    SidebarView()
#endif
  }
}

struct RootView_Previews: PreviewProvider {
  static var previews: some View {
    RootView()
  }
}
