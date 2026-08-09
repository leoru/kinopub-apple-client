//
//  PosterStyle.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI

/// Fixed-size poster frames for legacy call sites (downloads, season list).
/// Prefer `CardAspect` + `ShelfMetrics` for shelves and grids.
public struct PosterStyle: ViewModifier {
  public enum Size {
    case small, regular, medium, big

    public var width: CGFloat {
      switch self {
      case .small: return 53
      case .regular: return 120
      case .medium: return 165
      case .big: return 250
      }
    }

    public var height: CGFloat {
      width / CardAspect.poster.ratio
    }
  }

  public enum Orientation {
    case vertical
    case horizontal
  }

  let size: Size
  let orientation: Orientation

  public func body(content: Content) -> some View {
    Group {
      switch orientation {
      case .vertical:
        content.frame(width: size.width, height: size.height)
      case .horizontal:
        // Landscape frame: width follows 16:9 from the poster height token.
        content.frame(width: size.height, height: size.height / CardAspect.landscape.ratio)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
#if !os(tvOS)
    .shadow(radius: 8)
#endif
  }
}

public extension View {
  func posterStyle(size: PosterStyle.Size, orientation: PosterStyle.Orientation) -> some View {
    modifier(PosterStyle(size: size, orientation: orientation))
  }
}
