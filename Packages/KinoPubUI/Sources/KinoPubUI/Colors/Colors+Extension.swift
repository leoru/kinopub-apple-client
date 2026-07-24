//
//  Color+Extension.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The palette. Only the accents are ours: backgrounds and type come from the system,
/// so the app sits in the same tones as the tab bar and the rest of the platform's
/// chrome. The hand-picked grey that used to back every screen read as washed-out
/// beside it, and its "text" grey (#B0B1B5) was never as bright as the system label.
extension Color {
  public struct KinoPub {
    public static let accent = Color("accent_color", bundle: .module)
    public static let accentRed = Color("accent_red_color", bundle: .module)
    public static let accentBlue = Color("accent_blue_color", bundle: .module)

    /// The page background — black on a TV in dark appearance.
    public static var background: Color {
#if os(macOS)
      Color(nsColor: .windowBackgroundColor)
#elseif os(tvOS)
      // tvOS has no `systemBackground` — it is unavailable, not merely different. The
      // platform's own background is black in dark appearance and white in light, so
      // resolve it the same way rather than picking a grey.
//      Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
        Color(uiColor: .clear)
#else
      Color(uiColor: .systemBackground)
#endif
    }

    /// Chrome that sits on the page: chips, pickers, info panels.
    public static let selectionBackground = Color.primary.opacity(0.14)

    /// Fills the frame of artwork that has not downloaded yet.
    public static let placeholder = Color.primary.opacity(0.08)

    public static let text = Color.primary
    public static let subtitle = Color.secondary
  }
}
