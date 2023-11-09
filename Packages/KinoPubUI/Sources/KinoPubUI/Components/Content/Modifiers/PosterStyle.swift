//
//  PosterStyle.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
/// A view modifier that applies a poster style to a view.
public struct PosterStyle: ViewModifier {
  /// The size options for the poster style.
  public enum Size {
    case small, regular, medium, big
    
    /// The width of the poster based on the size option.
    public var width: CGFloat {
      switch self {
      case .small: return 53
      case .regular: return 120
      case .medium: return 165
      case .big: return 250
      }
    }
    
    /// The height of the poster based on the size option.
    public var height: CGFloat {
      switch self {
      case .small: return 80
      case .regular: return 180
      case .medium: return 250
      case .big: return 375
      }
    }
  }
  
  public enum Orientation {
    case vertical
    case horizontal
  }
  
  let size: Size
  let orientation: Orientation
  
  public func body(content: Content) -> some View {
    var result: AnyView = AnyView(content)
    
    if orientation == .vertical {
      result = AnyView(result.frame(width: size.width, height: size.height))
    } else {
      result = AnyView(result.frame(width: size.height, height: size.width))
    }
    
    return result
      .cornerRadius(8)
      .shadow(radius: 8)
  }
}

public extension View {
  /// Applies the poster style to a view with the specified size option.
  ///
  /// - Parameter size: The size option for the poster style.
  /// - Parameter orientation: The orientation option for the poster style.
  /// - Returns: A modified view with the poster style applied.
  func posterStyle(size: PosterStyle.Size, orientation: PosterStyle.Orientation) -> some View {
    return ModifiedContent(content: self, modifier: PosterStyle(size: size, orientation: orientation))
  }
}
