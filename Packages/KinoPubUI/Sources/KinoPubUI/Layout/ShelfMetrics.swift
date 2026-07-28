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

  /// Poster shelves / gallery grids. TV branch is the HIG 6-column table
  /// (80 inset, 40 gutter → ~260pt cards on a 1920pt canvas).
  public static func posters(width: CGFloat, typeSize: DynamicTypeSize) -> Self {
    let base: Self = switch width {
    case ..<420:  .init(inset: 16, gutter: 12, columns: 3)
    case ..<700:  .init(inset: 20, gutter: 16, columns: 4)
    case ..<1100: .init(inset: 24, gutter: 20, columns: 5)
    case ..<1600: .init(inset: 32, gutter: 28, columns: 6)
    default:      .init(inset: 80, gutter: 40, columns: 6)
    }
    guard typeSize.isAccessibilitySize else { return base }
    return .init(inset: base.inset, gutter: base.gutter, columns: max(2, base.columns - 2))
  }

  /// Landscape shelves (Continue Watching, episode rail): one fewer column so
  /// the wider card still fits the same inset/gutter grid.
  public static func landscape(width: CGFloat, typeSize: DynamicTypeSize) -> Self {
    let p = posters(width: width, typeSize: typeSize)
    return .init(inset: p.inset, gutter: p.gutter, columns: max(2, p.columns - 1))
  }

  /// Card width implied by this metrics for a given container width.
  public func cardWidth(in containerWidth: CGFloat) -> CGFloat {
    let usable = containerWidth - inset * 2 - gutter * CGFloat(max(columns - 1, 0))
    return max(1, usable / CGFloat(columns))
  }
}
