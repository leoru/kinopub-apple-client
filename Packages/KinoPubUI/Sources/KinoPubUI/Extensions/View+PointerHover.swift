//
//  View+PointerHover.swift
//  KinoPubUI
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public extension View {
  /// macOS: swap in the pointing-hand cursor while the pointer is over the view.
  /// No-op elsewhere — iPad pointer hover still works via `onHover` on the caller.
  /// Pass `enabled: false` when the view looks interactive but does not open anything.
  func pointingHandCursorOnHover(enabled: Bool = true) -> some View {
#if os(macOS)
    onHover { hovering in
      guard enabled else { return }
      if hovering {
        NSCursor.pointingHand.push()
      } else {
        NSCursor.pop()
      }
    }
#else
    self
#endif
  }
}
