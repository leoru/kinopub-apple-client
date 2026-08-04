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

    /// The page background. Must stay **opaque** on every platform: a transparent
    /// token silently turns every `.background(…)` into a no-op and every
    /// `.opacity(…)` scrim built on it into nothing at all.
    ///
    /// tvOS ships no semantic background colour — `UIColor.systemBackground` and
    /// friends are `API_UNAVAILABLE(tvos)`, because a TV app is expected to bring
    /// its own content backdrop. The app is dark-only, so the TV base is real
    /// black, matching the window root underneath. Liquid Glass samples the
    /// *content* above this fill, not the fill itself.
    public static var background: Color {
#if os(macOS)
      Color(nsColor: .windowBackgroundColor)
#elseif os(tvOS)
      Color.black
#else
      Color(uiColor: .systemBackground)
#endif
    }

    /// Chrome that sits on the page: chips, pickers, info panels.
    public static let selectionBackground = Color.primary.opacity(0.14)

    /// Opaque stand-in for Liquid Glass when sampling the backdrop is wrong:
    /// Reduce Transparency, Increase Contrast, or an A12-class Apple TV drawing
    /// over live video. See `kinoGlass` / `kinoPlayerGlass`. Revisit at the
    /// light-theme stage — the app is dark-only today.
    public static let glassSubstitute = Color(white: 0.12)

    /// Fills the frame of artwork that has not downloaded yet.
    public static let placeholder = Color.primary.opacity(0.08)

    public static let text = Color.primary
      public static let subtitle = Color.secondary
  }
}
