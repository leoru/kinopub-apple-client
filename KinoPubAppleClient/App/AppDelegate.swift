//
//  AppDelegate.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {

  // This flag is used to lock orientation on the player view
  static var orientationLock = UIInterfaceOrientationMask.all

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    return true
  }

  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
}
#endif

#if os(tvOS)
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    return true
  }
}
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {

  var window: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // No Safari-style tabs. AppKit merges new windows into the frontmost window's tab
    // group by default, which swallowed the player: it opened as a tab of the library
    // window, wearing that window's back button and title bar, and ⌘W then closed the
    // whole app window instead of the film. A player is not a document you keep several
    // of in one frame.
    NSWindow.allowsAutomaticWindowTabbing = false
  }
}
#endif
