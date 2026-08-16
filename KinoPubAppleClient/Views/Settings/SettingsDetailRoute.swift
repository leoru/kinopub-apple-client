//
//  SettingsDetailRoute.swift
//  KinoPubAppleClient
//

import Foundation

#if !os(tvOS)
/// Nested Settings destinations pushed inside a category’s detail stack.
enum SettingsDetailRoute: Hashable {
  case devicesList
  case storage
  case sections
  /// Not DEBUG-only on purpose: the launches worth reading a log for happen on a real
  /// Apple TV running a TestFlight build, with no Xcode attached.
  case networkLog
#if DEBUG
  case streamSurvey
  /// Opens the in-process UI lab (iOS). macOS uses `openWindow` instead.
  case uiLab(UILabChrome)
  case typeStyles
  case libraryLab
#endif
}
#endif
