//
//  Metrics.swift
//  KinoPubUI
//

import SwiftUI

/// Shared hairlines, radii and spacing. Prefer `@ScaledMetric` at call sites for
/// square / circular chrome; these are the unscaled baselines.
///
/// Two of these decide the rhythm of a page of sections and must not be re-picked at a
/// call site: `sectionHeaderSpacing` is header → the cards under it, `rowSpacing` is
/// one section → the next. A rail adds its own focus padding inside both, so the
/// *visible* distance is the constant only while every rail pads by the same amount —
/// see `landscapeFocusPadding`, and `MediaPosterShelf`, which subtracts it back out.
public enum Metrics {
  public static let cardCornerRadius: CGFloat = 14
  public static let progressBarHeight: CGFloat = 6
  public static let hairline: CGFloat = 0.5

#if os(tvOS)
  public static let cardCaptionSpacing: CGFloat = 20
  public static let rowSpacing: CGFloat = 40
  public static let sectionHeaderSpacing: CGFloat = 28
  public static let focusPadding: CGFloat = 32
  /// Extra room for Continue Watching / landscape focus lift (wider tiles grow more
  /// in absolute points; poster shelves keep `focusPadding`).
  public static let landscapeFocusPadding: CGFloat = 56
  /// Apple TV Alerts / Light / Glyph + Title squircle.
  public static let hudSide: CGFloat = 220
  public static let hudCornerRadius: CGFloat = 36
  public static let hudGlyphPointSize: CGFloat = 56
  public static let hudGlyphTitleSpacing: CGFloat = 16
  public static let hudContentInset: CGFloat = 28
#else
  public static let cardCaptionSpacing: CGFloat = 6
  public static let rowSpacing: CGFloat = 36
  public static let sectionHeaderSpacing: CGFloat = 18
  public static let focusPadding: CGFloat = 4
  /// The same as `focusPadding` off tvOS, and that is the point. It is lift room for
  /// the focus engine, which only exists on TV; giving landscape rails their own
  /// number here made Continue Watching sit 4pt further from its header than every
  /// poster rail, and 4pt further from the section under it.
  public static let landscapeFocusPadding: CGFloat = focusPadding
  /// Music-style confirmation HUD.
  public static let hudSide: CGFloat = 154
  public static let hudCornerRadius: CGFloat = 28
  public static let hudGlyphPointSize: CGFloat = 44
  public static let hudGlyphTitleSpacing: CGFloat = 12
  public static let hudContentInset: CGFloat = 20
#endif
}
