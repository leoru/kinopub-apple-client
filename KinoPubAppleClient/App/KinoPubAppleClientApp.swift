//
//  KinoPubAppleClientApp.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import FirebaseCore

@main
struct KinoPubAppleClientApp: App {
  
  #if os(iOS)
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  #endif
  
  #if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  #endif
  
  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.appContext, AppContext.shared)
    }
  }
}
