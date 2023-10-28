//
//  KinoPubAppleClientApp.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 17.07.2023.
//

import SwiftUI
import FirebaseCore

enum WindowSize {
  static let macos = CGSize(width: 1280, height: 720)
}

@main
struct KinoPubAppleClientApp: App {
  
  @StateObject var navigationState = NavigationState()
  @StateObject var errorHandler = ErrorHandler()
  @StateObject var authState = AuthState(authService: AppContext.shared.authService,
                                         accessTokenService: AppContext.shared.accessTokenService)
  
#if os(macOS)
  @StateObject var windowSettings = WindowSettings()
#endif
  
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
        .environmentObject(navigationState)
        .environmentObject(authState)
        .environmentObject(errorHandler)
#if os(macOS)
        .frame(minWidth: WindowSize.macos.width, minHeight: WindowSize.macos.height)
#endif
    }
#if os(macOS)
    .windowResizability(.contentSize)
#endif
    
#if os(macOS)
    Settings {
      SettingsView()
        .environmentObject(windowSettings)
    }
#endif
  }
}
