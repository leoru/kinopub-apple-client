//
//  ProgressiveBlur.swift
//
//

import Foundation
import SwiftUI

/// Stacks progressively stronger blurred copies of a view, each masked to start
/// lower than the last, so the image stays sharp at the top and dissolves toward the
/// bottom. SwiftUI has no variable-radius blur, and a single blurred layer faded in
/// with a gradient produces a visible seam where it starts.
public struct ProgressiveBlur<Content: View>: View {

  private let content: Content
  private let startPoint: CGFloat
  private let maxRadius: CGFloat
  private let layers: Int

  /// - Parameters:
  ///   - startPoint: where the blur begins, 0 (top) to 1 (bottom).
  ///   - maxRadius: blur radius at the very bottom.
  ///   - layers: number of steps; more is smoother and costlier.
  public init(startPoint: CGFloat = 0.4,
              maxRadius: CGFloat = 40,
              layers: Int = 4,
              @ViewBuilder content: () -> Content) {
    self.content = content()
    self.startPoint = startPoint
    self.maxRadius = maxRadius
    self.layers = max(1, layers)
  }

  public var body: some View {
    ZStack {
      content

      ForEach(0..<layers, id: \.self) { layer in
        let progress = CGFloat(layer + 1) / CGFloat(layers)
        // Each layer fades in over the span left below the previous one, so their
        // gradients overlap and no single edge is visible.
        let fadeStart = startPoint + (1 - startPoint) * (CGFloat(layer) / CGFloat(layers))

        content
          .blur(radius: maxRadius * progress, opaque: true)
          .mask(
            LinearGradient(stops: [
              .init(color: .clear, location: min(fadeStart, 1)),
              .init(color: .black, location: min(fadeStart + (1 - startPoint) / CGFloat(layers), 1))
            ], startPoint: .top, endPoint: .bottom)
          )
      }
    }
  }
}
