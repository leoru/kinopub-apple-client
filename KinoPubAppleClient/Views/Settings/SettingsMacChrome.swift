//
//  SettingsMacChrome.swift
//  KinoPubAppleClient
//
//  System Settings–style detail chrome for our custom Settings window (not the
//  SwiftUI Settings scene). Public API only — no swizzling.
//

import SwiftUI

#if os(macOS)
extension View {
  /// Root panes: disabled Back + Forward beside the system navigation title.
  /// Nested pushes keep the system Back; we only leave a disabled Forward.
  func settingsMacChrome(title: LocalizedStringKey, isRoot: Bool = true) -> some View {
    self
      .navigationTitle(title)
      .toolbar {
        ToolbarItem(placement: .navigation) {
          HStack(spacing: 6) {
            if isRoot {
              Button("Back", systemImage: "chevron.left") {}
                .disabled(true)
                .help("Back")
            }
            Button("Forward", systemImage: "chevron.right") {}
              .disabled(true)
              .help("Forward")
          }
        }
      }
  }
}
#endif
