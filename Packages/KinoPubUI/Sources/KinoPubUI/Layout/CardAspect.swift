//
//  CardAspect.swift
//  KinoPubUI
//

import CoreGraphics

/// Aspect ratios for shelf / grid cards. Width is owned by `ShelfMetrics`; height
/// follows from the aspect.
public enum CardAspect: Sendable, Equatable {
  /// Catalog posters — 2:3.
  case poster
  /// Continue Watching / episode stills — 16:9.
  case landscape
  /// Reserved (music / podcasts).
  case square

  /// Width ÷ height for SwiftUI `.aspectRatio(_:contentMode:)`.
  public var ratio: CGFloat {
    switch self {
    case .poster: return 2.0 / 3.0
    case .landscape: return 16.0 / 9.0
    case .square: return 1.0
    }
  }
}
