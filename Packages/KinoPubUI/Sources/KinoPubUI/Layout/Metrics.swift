//
//  Metrics.swift
//  KinoPubUI
//

import SwiftUI

/// Shared hairlines, radii and spacing. Prefer `@ScaledMetric` at call sites for
/// square / circular chrome; these are the unscaled baselines.
public enum Metrics {
  public static let cardCornerRadius: CGFloat = 14
  public static let progressBarHeight: CGFloat = 6
  public static let hairline: CGFloat = 0.5

#if os(tvOS)
  public static let cardCaptionSpacing: CGFloat = 20
  public static let rowSpacing: CGFloat = 40
  public static let focusPadding: CGFloat = 32
  /// Apple TV Alerts / Light / Glyph + Title squircle.
  public static let hudSide: CGFloat = 220
  public static let hudCornerRadius: CGFloat = 36
  public static let hudGlyphPointSize: CGFloat = 56
  public static let hudGlyphTitleSpacing: CGFloat = 16
  public static let hudContentInset: CGFloat = 28
#else
  public static let cardCaptionSpacing: CGFloat = 6
  public static let rowSpacing: CGFloat = 24
  public static let focusPadding: CGFloat = 4
  /// Music-style confirmation HUD.
  public static let hudSide: CGFloat = 154
  public static let hudCornerRadius: CGFloat = 28
  public static let hudGlyphPointSize: CGFloat = 44
  public static let hudGlyphTitleSpacing: CGFloat = 12
  public static let hudContentInset: CGFloat = 20
#endif
}
