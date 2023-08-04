//
//  PosterStyle.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI

public struct PosterStyle: ViewModifier {
  public enum Size {
    case small, medium, big

    public var width: CGFloat {
      switch self {
      case .small: return 53
      case .medium: return 165
      case .big: return 250
      }
    }

    public var height: CGFloat {
      switch self {
      case .small: return 80
      case .medium: return 250
      case .big: return 375
      }
    }
  }

  let size: Size

  public func body(content: Content) -> some View {
    return content
      .frame(width: size.width, height: size.height)
      .cornerRadius(8)
      .shadow(radius: 8)
  }
}

extension View {
  func posterStyle( size: PosterStyle.Size) -> some View {
    return ModifiedContent(content: self, modifier: PosterStyle(size: size))
  }
}
