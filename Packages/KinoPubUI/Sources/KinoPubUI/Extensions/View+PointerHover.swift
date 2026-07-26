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
  func pointingHandCursorOnHover() -> some View {
#if os(macOS)
    onHover { hovering in
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
