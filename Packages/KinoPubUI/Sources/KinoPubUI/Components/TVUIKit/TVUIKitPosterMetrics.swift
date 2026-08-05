#if os(tvOS)
//
//  TVUIKitPosterMetrics.swift
//  KinoPubUI
//
//  One sizing model for shelves AND grids — same `ShelfMetrics` column equation.
//  A horizontal shelf is the same poster grid scrolled sideways.
//

import CoreGraphics
import SwiftUI

public enum TVUIKitPosterMetrics {
  /// Extra group height beneath tiles for the focus-scale growth.
  public static let focusGrowthPadding: CGFloat = 48
  /// Landscape / Continue Watching — wider tiles need more absolute lift room.
  public static let landscapeFocusGrowthPadding: CGFloat = 72
  /// On-focus caption under poster.
  public static let captionHeight: CGFloat = 44
  public static let captionTopPadding: CGFloat = 8
  public static let cornerRadius: CGFloat = 16

  public static func posterSize(containerWidth: CGFloat, typeSize: DynamicTypeSize = .large) -> CGSize {
    let metrics = ShelfMetrics.posters(width: containerWidth, typeSize: typeSize)
    let width = metrics.cardWidth(in: containerWidth)
    let height = width / CardAspect.poster.ratio
    return CGSize(width: width, height: height)
  }

  public static func landscapeSize(containerWidth: CGFloat, typeSize: DynamicTypeSize = .large) -> CGSize {
    let metrics = ShelfMetrics.landscape(width: containerWidth, typeSize: typeSize)
    let width = metrics.cardWidth(in: containerWidth)
    let height = width / CardAspect.landscape.ratio
    return CGSize(width: width, height: height)
  }

  public static func shelfMetrics(isLandscape: Bool,
                                  containerWidth: CGFloat,
                                  typeSize: DynamicTypeSize = .large) -> ShelfMetrics {
    isLandscape
      ? .landscape(width: containerWidth, typeSize: typeSize)
      : .posters(width: containerWidth, typeSize: typeSize)
  }

  public static func itemSize(isLandscape: Bool,
                              containerWidth: CGFloat,
                              typeSize: DynamicTypeSize = .large) -> CGSize {
    let tile = isLandscape
      ? landscapeSize(containerWidth: containerWidth, typeSize: typeSize)
      : posterSize(containerWidth: containerWidth, typeSize: typeSize)
    let caption: CGFloat
    if isLandscape {
      // Title + episode line under CW tiles (same reserved caption as SwiftUI path).
      caption = captionTopPadding + captionHeight
    } else {
      caption = captionTopPadding + captionHeight
    }
    return CGSize(width: tile.width, height: tile.height + caption)
  }

  public static func railHeight(isLandscape: Bool,
                                containerWidth: CGFloat,
                                typeSize: DynamicTypeSize = .large) -> CGFloat {
    let growth = isLandscape ? landscapeFocusGrowthPadding : focusGrowthPadding
    return itemSize(isLandscape: isLandscape, containerWidth: containerWidth, typeSize: typeSize).height
      + growth
  }
}
#endif
