//
//  ShelfMetrics.swift
//  KinoPubUI
//

import SwiftUI

/// Page inset, gutter and column count for one shelf or grid. Derived from
/// container width + Dynamic Type — no `#if os` branches.
public struct ShelfMetrics: Equatable, Sendable {
  public let inset: CGFloat
  public let gutter: CGFloat
  public let columns: Int

  public init(inset: CGFloat, gutter: CGFloat, columns: Int) {
    self.inset = inset
    self.gutter = gutter
    self.columns = columns
  }

  /// Poster shelves / gallery grids.
  public static func posters(width: CGFloat, typeSize: DynamicTypeSize) -> Self {
#if os(tvOS)
    let base = tvPosters(width: width)
#else
    let base: Self = switch width {
    case ..<420:  .init(inset: 20, gutter: 20, columns: 3)
    case ..<700:  .init(inset: 40, gutter: 20, columns: 4)
    case ..<1000: .init(inset: 40, gutter: 28, columns: 5)
    case ..<1200: .init(inset: 40, gutter: 28, columns: 6)
    case ..<1400: .init(inset: 40, gutter: 32, columns: 7)
    case ..<1600: .init(inset: 40, gutter: 32, columns: 8)
    default:      .init(inset: 40, gutter: 20, columns: 6)
    }
#endif
    guard typeSize.isAccessibilitySize else { return base }
    return .init(inset: base.inset, gutter: base.gutter, columns: max(2, base.columns - 2))
  }

#if os(tvOS)
  /// The HIG 6-column table on the full 1920pt canvas, expressed as the card width it
  /// produces. On TV this is the fixed quantity: a poster has to stay readable from the
  /// sofa, so a narrower container gets *fewer* cards, never smaller ones.
  public static let tvCardWidth: CGFloat = 290

  /// What five landscape columns come to on the same 1920pt canvas.
  public static let tvLandscapeCardWidth: CGFloat = 352

  /// Width alone cannot classify a canvas. 1500pt is a Mac window at arm's length —
  /// eight columns are right there — and it is also the tvOS Library grid next to its
  /// 420pt sidebar, still viewed across a room. The shared table reads that as "wide
  /// tablet" and halved the poster to ~150pt the moment a sidebar appeared, so tvOS
  /// sizes to `tvCardWidth` and lets the container decide how many fit.
  private static func tvPosters(width: CGFloat) -> Self {
    let inset: CGFloat = 40
    let gutter: CGFloat = 20
    let usable = max(width - inset * 2, 1)
    // Cards + the gutters between them: n·card + (n−1)·gutter ≤ usable.
    let columns = Int(((usable + gutter) / (tvCardWidth + gutter)).rounded())
    return .init(inset: inset, gutter: gutter, columns: max(2, columns))
  }
#endif

  /// Landscape shelves (Continue Watching, episode rail): one fewer column so
  /// the wider card still fits the same inset/gutter grid.
  public static func landscape(width: CGFloat, typeSize: DynamicTypeSize) -> Self {
    let p = posters(width: width, typeSize: typeSize)
#if os(tvOS)
    // "One fewer column" only tracks the wider card while columns are plentiful. Once a
    // sidebar takes the count down to four, subtracting one overshoots — the tile grows
    // past its full-screen size. Size to the target width here too.
    guard !typeSize.isAccessibilitySize else {
      return .init(inset: p.inset, gutter: p.gutter, columns: max(2, p.columns - 1))
    }
    let usable = max(width - p.inset * 2, 1)
    let columns = Int(((usable + p.gutter) / (tvLandscapeCardWidth + p.gutter)).rounded())
    return .init(inset: p.inset, gutter: p.gutter, columns: max(2, columns))
#else
    return .init(inset: p.inset, gutter: p.gutter, columns: max(2, p.columns - 1))
#endif
  }

  /// Contained 16:9 Home banner cards. Phone fills the width (1 column); wide
  /// canvases keep ~2 columns so each card stays a padded hero with neighbors
  /// peeking — not a full-bleed mural.
  public static func banner(width: CGFloat, typeSize: DynamicTypeSize) -> Self {
    let p = posters(width: width, typeSize: typeSize)
    let columns: Int = width < 900 ? 1 : 2
    return .init(inset: p.inset, gutter: max(p.gutter, 24), columns: columns)
  }

  /// Card width implied by this metrics for a given container width.
  public func cardWidth(in containerWidth: CGFloat) -> CGFloat {
    let usable = containerWidth - inset * 2 - gutter * CGFloat(max(columns - 1, 0))
    return max(1, usable / CGFloat(columns))
  }
}
