#if os(tvOS)
//
//  TVUIKitPosterMetrics.swift
//  KinoPubUI
//
//  One sizing model for shelves AND grids — same `ShelfMetrics` column equation.
//  A horizontal shelf is the same poster grid scrolled sideways.
//
//  Every focus-room number here is derived from the tile, not chosen: a focused tvOS
//  tile grows by a fraction of its own size, so a constant reserve is either wasted
//  space on a small tile or a collision on a large one.
//

import CoreGraphics
import SwiftUI

public enum TVUIKitPosterMetrics {
  /// On-focus caption under the poster: **two lines, and only ever two** — the title
  /// and `TVUIKitCardText.secondary`. Sized for `.callout` over `.caption1` at tvOS
  /// metrics; a third line is not a layout question, it is a decision that was made
  /// against (see the tvOS cell standard).
  public static let captionHeight: CGFloat = 72
  public static let captionTopPadding: CGFloat = 8
  public static let captionLineSpacing: CGFloat = 2
  public static let cornerRadius: CGFloat = 16

  /// Room a tile needs above and below itself for the focus lift, plus a gap so two
  /// stacked rows do not touch when one of them is focused. Same rule as
  /// `ShelfMetrics.tvGutter`, applied to the tile's *height*.
  public static func focusGrowthPadding(tileHeight: CGFloat) -> CGFloat {
    (tileHeight * ShelfMetrics.tvFocusGrowth / 2).rounded() + ShelfMetrics.tvMinimumGap
  }

  public static func posterSize(containerWidth: CGFloat,
                                typeSize: DynamicTypeSize = .large,
                                safeArea: CGFloat = 0) -> CGSize {
    let metrics = ShelfMetrics.posters(width: containerWidth, typeSize: typeSize, safeArea: safeArea)
    let width = metrics.cardWidth(in: containerWidth)
    let height = width / CardAspect.poster.ratio
    return CGSize(width: width, height: height)
  }

  public static func landscapeSize(containerWidth: CGFloat,
                                   typeSize: DynamicTypeSize = .large,
                                   safeArea: CGFloat = 0) -> CGSize {
    let metrics = ShelfMetrics.landscape(width: containerWidth, typeSize: typeSize, safeArea: safeArea)
    let width = metrics.cardWidth(in: containerWidth)
    let height = width / CardAspect.landscape.ratio
    return CGSize(width: width, height: height)
  }

  public static func shelfMetrics(isLandscape: Bool,
                                  containerWidth: CGFloat,
                                  typeSize: DynamicTypeSize = .large,
                                  safeArea: CGFloat = 0) -> ShelfMetrics {
    isLandscape
      ? .landscape(width: containerWidth, typeSize: typeSize, safeArea: safeArea)
      : .posters(width: containerWidth, typeSize: typeSize, safeArea: safeArea)
  }

  public static func itemSize(isLandscape: Bool,
                              containerWidth: CGFloat,
                              typeSize: DynamicTypeSize = .large,
                              safeArea: CGFloat = 0) -> CGSize {
    let tile = isLandscape
      ? landscapeSize(containerWidth: containerWidth, typeSize: typeSize, safeArea: safeArea)
      : posterSize(containerWidth: containerWidth, typeSize: typeSize, safeArea: safeArea)
    return CGSize(width: tile.width,
                  height: tile.height + captionTopPadding + captionHeight)
  }

  /// Room reserved above and below the tiles of a section, for the focus lift.
  public static func sectionFocusPadding(isLandscape: Bool,
                                         containerWidth: CGFloat,
                                         typeSize: DynamicTypeSize = .large,
                                         safeArea: CGFloat = 0) -> CGFloat {
    let tile = isLandscape
      ? landscapeSize(containerWidth: containerWidth, typeSize: typeSize, safeArea: safeArea)
      : posterSize(containerWidth: containerWidth, typeSize: typeSize, safeArea: safeArea)
    return focusGrowthPadding(tileHeight: tile.height)
  }

  public static func railHeight(isLandscape: Bool,
                                containerWidth: CGFloat,
                                typeSize: DynamicTypeSize = .large,
                                safeArea: CGFloat = 0) -> CGFloat {
    let item = itemSize(isLandscape: isLandscape,
                        containerWidth: containerWidth,
                        typeSize: typeSize,
                        safeArea: safeArea)
    let padding = sectionFocusPadding(isLandscape: isLandscape,
                                      containerWidth: containerWidth,
                                      typeSize: typeSize,
                                      safeArea: safeArea)
    return item.height + padding * 2
  }
}
#endif
