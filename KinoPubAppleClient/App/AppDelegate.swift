//
//  AppDelegate.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import FirebaseCore

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
  static var orientationLock = UIInterfaceOrientationMask.all
  
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    return true
  }
  
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
}
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    FirebaseApp.configure()
  }
}
#endif
