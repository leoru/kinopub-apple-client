//
//  ShelfMetrics.swift
//  KinoPubUI
//

import SwiftUI

/// The horizontal margin the grid on this screen actually landed on, published so a
/// header above it lines up with the first column instead of with a number it happens
/// to hold itself. `ContentItemsListView` writes it; anything drawn as that view's
/// header should read it rather than repeat an inset.
public struct ShelfGridInsetKey: EnvironmentKey {
  public static let defaultValue: CGFloat = 40
}

public extension EnvironmentValues {
  var shelfGridInset: CGFloat {
    get { self[ShelfGridInsetKey.self] }
    set { self[ShelfGridInsetKey.self] = newValue }
  }
}

/// What a container has to measure to build its `ShelfMetrics`: how wide it is, and
/// how much of the platform's safe area it is responsible for itself. One value so a
/// single `onGeometryChange` carries both and they can never disagree by a frame.
public struct ShelfGeometry: Equatable, Sendable {
  public var width: CGFloat
  public var safeArea: CGFloat

  public init(width: CGFloat, safeArea: CGFloat) {
    self.width = width
    self.safeArea = safeArea
  }
}

/// Page inset, gutter and column count for one shelf or grid. Derived from
/// container width + Dynamic Type — no `#if os` branches.
public struct ShelfMetrics: Equatable, Sendable {
  public let inset: CGFloat
  public let gutter: CGFloat
  public let columns: Int
  /// When set, every card is exactly this wide and the leftover becomes slack instead
  /// of being divided among the columns. tvOS uses it so a poster is the *same size*
  /// in a full-width Home rail and in a grid beside a sidebar — see `tvCardWidth`.
  public let fixedCardWidth: CGFloat?

  public init(inset: CGFloat, gutter: CGFloat, columns: Int, fixedCardWidth: CGFloat? = nil) {
    self.inset = inset
    self.gutter = gutter
    self.columns = columns
    self.fixedCardWidth = fixedCardWidth
  }

  /// Poster shelves / gallery grids.
  ///
  /// `safeArea` is the container's own leading/trailing safe-area inset, when the
  /// caller measured one. Screens differ: a grid sits inside SwiftUI's safe area
  /// already (0 here), while the detail page ignores it horizontally and must supply
  /// the overscan margin itself. Taking the larger of the two is right in both cases —
  /// never doubled, never inside overscan.
  public static func posters(width: CGFloat,
                             typeSize: DynamicTypeSize,
                             safeArea: CGFloat = 0) -> Self {
#if os(tvOS)
    let base = tvPosters(width: width, safeArea: safeArea)
#else
    let base: Self = switch width {
    // Every phone in portrait, up to the 440pt Pro Max, stays on this step. The
    // break used to sit at 420, which put the largest phones one step up: four
    // columns behind a 40pt margin came to a 72pt poster, half the size the same
    // phone showed 40pt earlier.
    case ..<520:  page(inset: 20, columns: 3)
    case ..<700:  page(inset: 40, columns: 4)
    case ..<1000: page(inset: 40, columns: 5)
    case ..<1200: page(inset: 40, columns: 6)
    case ..<1400: page(inset: 40, columns: 7)
    case ..<1600: page(inset: 40, columns: 8)
    // The ladder does not stop at the last named step — it keeps adding a column every
    // `columnStep`, which is what holds a poster near 170pt on a wide display. Falling
    // back to a *smaller* count here is what made the cards inflate the moment a Mac
    // window passed 1600pt: eight columns at 1599pt, six much larger ones at 1601pt.
    default:      page(inset: 40, columns: 8 + Int((width - 1600) / columnStep))
    }
#endif
    guard typeSize.isAccessibilitySize else { return base }
    return .init(inset: base.inset,
                 gutter: base.gutter,
                 columns: max(2, base.columns - 2),
                 fixedCardWidth: base.fixedCardWidth)
  }

#if os(tvOS)
  /// The HIG 6-column table on the full 1920pt canvas, expressed as the card width it
  /// produces. On TV this is the fixed quantity: a poster has to stay readable from the
  /// sofa, so a narrower container gets *fewer* cards, never smaller ones — and a
  /// poster is the same size in a rail and in a grid, which is the whole point.
  public static let tvCardWidth: CGFloat = 290

  /// What five landscape columns come to on the same 1920pt canvas.
  public static let tvLandscapeCardWidth: CGFloat = 352

  /// Design margin inside whatever the container hands us. Only wins when the
  /// container is already inside the platform's safe area (`safeArea == 0`).
  public static let tvContentMargin: CGFloat = 40

  /// A focused tvOS tile grows about a tenth of its width, half of it into each
  /// neighbour's side of the gutter. A constant gutter therefore reads fine at rest and
  /// collides on focus, which is exactly what a 20pt gutter under a 290pt poster did.
  /// The gutter has to carry the growth *and* still leave a visible gap.
  public static let tvFocusGrowth: CGFloat = 0.1
  public static let tvMinimumGap: CGFloat = 24

  public static func tvGutter(cardWidth: CGFloat) -> CGFloat {
    (cardWidth * tvFocusGrowth).rounded() + tvMinimumGap
  }

  /// Width alone cannot classify a canvas. 1500pt is a Mac window at arm's length —
  /// eight columns are right there — and it is also the tvOS Library grid next to its
  /// 420pt sidebar, still viewed across a room. The shared table reads that as "wide
  /// tablet" and halved the poster to ~150pt the moment a sidebar appeared, so tvOS
  /// pins `tvCardWidth` and lets the container decide how many fit.
  private static func tvPosters(width: CGFloat, safeArea: CGFloat) -> Self {
    let inset = max(tvContentMargin, safeArea)
    let gutter = tvGutter(cardWidth: tvCardWidth)
    let usable = max(width - inset * 2, 1)
    // Cards + the gutters between them: n·card + (n−1)·gutter ≤ usable. Floored, not
    // rounded — with the card width pinned, rounding up overflows the container
    // instead of quietly shrinking the cards.
    let columns = Int((usable + gutter) / (tvCardWidth + gutter))
    return .init(inset: inset,
                 gutter: gutter,
                 columns: max(2, columns),
                 fixedCardWidth: tvCardWidth)
  }
#endif

  /// How much width buys one more column past the last named breakpoint. The named
  /// steps sit ~200pt apart for the same reason: that is one poster plus its gutter.
  private static let columnStep: CGFloat = 200

  /// One page of a grid or shelf, from the single number that decides its rhythm.
  ///
  /// The gutter is half the inset, always. The inset is the margin the view deliberately
  /// holds at its left and right edges; the gap between two cards reads as half of that
  /// because neighbours share it, so a card sits the same visual distance from its
  /// neighbour as the row does from the edge of the screen. Hand-picked gutters are what
  /// made the gap between two posters on a phone as wide as the page margin itself, and
  /// then a different width again on every breakpoint.
  private static func page(inset: CGFloat, columns: Int) -> Self {
    .init(inset: inset, gutter: inset / 2, columns: columns)
  }

  /// Landscape shelves (Continue Watching, episode rail): one fewer column so
  /// the wider card still fits the same inset/gutter grid.
  public static func landscape(width: CGFloat,
                               typeSize: DynamicTypeSize,
                               safeArea: CGFloat = 0) -> Self {
    let p = posters(width: width, typeSize: typeSize, safeArea: safeArea)
#if os(tvOS)
    let gutter = tvGutter(cardWidth: tvLandscapeCardWidth)
    // "One fewer column" only tracks the wider card while columns are plentiful. Once a
    // sidebar takes the count down to four, subtracting one overshoots — the tile grows
    // past its full-screen size. Size to the target width here too.
    guard !typeSize.isAccessibilitySize else {
      return .init(inset: p.inset,
                   gutter: gutter,
                   columns: max(2, p.columns - 1),
                   fixedCardWidth: tvLandscapeCardWidth)
    }
    let usable = max(width - p.inset * 2, 1)
    let columns = Int((usable + gutter) / (tvLandscapeCardWidth + gutter))
    return .init(inset: p.inset,
                 gutter: gutter,
                 columns: max(2, columns),
                 fixedCardWidth: tvLandscapeCardWidth)
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
    // Same gutter as the rails underneath it. A banner-only number (this was
    // `max(p.gutter, 24)`) put a different gap on the top of Home than on every row
    // below it, on the one screen where both are in view at once.
    return .init(inset: p.inset, gutter: p.gutter, columns: columns)
  }

  /// Leading/trailing margin for a **grid**: the page inset plus half of whatever a
  /// pinned card width leaves over at the end of a row, so the rows sit centred rather
  /// than packed left with a hole on the right.
  ///
  /// A section header above that grid must use this same number, not `inset` — that is
  /// the whole reason it is one function instead of a calculation inside the layout.
  /// Shelves keep `inset`: a rail scrolls, so its leftover is not a hole, and centring
  /// it would push the first card away from the header above it.
  public func gridInset(in containerWidth: CGFloat) -> CGFloat {
    guard fixedCardWidth != nil else { return inset }
    let used = cardWidth(in: containerWidth) * CGFloat(columns)
      + gutter * CGFloat(max(columns - 1, 0))
    let remainder = max(0, containerWidth - inset * 2 - used)
    return inset + remainder / 2
  }

  /// Card width implied by this metrics for a given container width.
  public func cardWidth(in containerWidth: CGFloat) -> CGFloat {
    // A pinned width does not divide the leftover among the columns — that is what
    // made the same poster a different size on every screen.
    if let fixedCardWidth { return fixedCardWidth }
    let usable = containerWidth - inset * 2 - gutter * CGFloat(max(columns - 1, 0))
    return max(1, usable / CGFloat(columns))
  }
}
