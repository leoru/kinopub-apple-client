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

#if os(macOS)
  /// Keeps the window toolbar the same height on every sidebar destination by
  /// reserving the accessory strip (Search fills it with filters). Back/forward
  /// stay system-owned — only appear when the stack can actually go.
  func macStableToolbarChrome(reserveAccessorySlot: Bool = true) -> some View {
    modifier(MacStableToolbarChromeModifier(reserveAccessorySlot: reserveAccessorySlot))
  }
#endif
}

#if os(macOS)
enum MacToolbarChrome {
  /// Shared accessory-bar id — Search filters and empty placeholders must match
  /// or the window grows a second strip.
  static let accessoryID = "mac-detail-accessory"
  static let accessoryMinHeight: CGFloat = 36
}

private struct MacStableToolbarChromeModifier: ViewModifier {
  var reserveAccessorySlot: Bool

  func body(content: Content) -> some View {
    content.toolbar {
      if reserveAccessorySlot {
        ToolbarItem(placement: .accessoryBar(id: MacToolbarChrome.accessoryID)) {
          Color.clear
            .frame(height: MacToolbarChrome.accessoryMinHeight)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        }
      }
    }
  }
}
#endif
