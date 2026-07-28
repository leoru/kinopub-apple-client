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
#else
  public static let cardCaptionSpacing: CGFloat = 6
  public static let rowSpacing: CGFloat = 24
  public static let focusPadding: CGFloat = 4
#endif
}
