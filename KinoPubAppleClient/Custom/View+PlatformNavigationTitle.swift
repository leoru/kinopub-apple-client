//
//  View+PlatformNavigationTitle.swift
//  KinoPubAppleClient
//

import SwiftUI

public extension View {
  /// On tvOS the tab bar already says where you are, and a large title below it just
  /// eats the top of the screen. Everywhere else the title carries its usual weight.
  @ViewBuilder
  func platformNavigationTitle(_ title: LocalizedStringKey) -> some View {
#if os(tvOS)
    self
#else
    navigationTitle(title)
#endif
  }

  @ViewBuilder
  func platformNavigationTitle(_ title: String) -> some View {
#if os(tvOS)
    self
#else
    navigationTitle(title)
#endif
  }
}
