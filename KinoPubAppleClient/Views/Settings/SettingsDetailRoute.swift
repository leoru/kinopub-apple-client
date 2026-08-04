//
//  SettingsDetailRoute.swift
//  KinoPubAppleClient
//

import Foundation

#if !os(tvOS)
/// Nested Settings destinations pushed inside a category’s detail stack.
enum SettingsDetailRoute: Hashable {
  case streamSurvey
}
#endif
