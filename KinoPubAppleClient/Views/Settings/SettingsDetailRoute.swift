//
//  SettingsDetailRoute.swift
//  KinoPubAppleClient
//

import Foundation

#if !os(tvOS)
/// Nested Settings destinations pushed inside a category’s detail stack.
enum SettingsDetailRoute: Hashable {
  case streamSurvey
#if DEBUG
  /// Opens the in-process UI lab (iOS). macOS uses `openWindow` instead.
  case uiLab(UILabChrome)
  case typeStyles
#endif
}
#endif
