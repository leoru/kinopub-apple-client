//
//  ProgressiveBlur.swift
//
//

import Foundation
import SwiftUI

/// Blurs a view progressively down its height: sharp at the top, fully blurred at the
/// bottom. Uses a Metal layer effect where available (a genuine variable-radius blur)
/// and falls back to stacked, masked blur layers on older systems.
public struct ProgressiveBlur<Content: View>: View {

  private let content: Content
  private let startPoint: CGFloat
  private let maxRadius: CGFloat
  private let layers: Int

  /// - Parameters:
  ///   - startPoint: where the blur begins, 0 (top) to 1 (bottom).
  ///   - maxRadius: blur radius at the very bottom.
  ///   - layers: fallback only — number of stacked steps.
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
    if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
      content.modifier(MetalVariableBlur(startPoint: startPoint, maxRadius: maxRadius))
    } else {
      stackedFallback
    }
  }

  /// Each layer is blurred harder and masked to start lower than the last, so their
  /// gradients overlap. A single blurred layer faded in with one gradient shows a
  /// visible edge where it begins.
  private var stackedFallback: some View {
    ZStack {
      content

      ForEach(0..<layers, id: \.self) { layer in
        let progress = CGFloat(layer + 1) / CGFloat(layers)
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

/// Drives `VariableBlur.metal`. `visualEffect` hands over the resolved size without
/// wrapping the content in a `GeometryReader`, which would change its layout.
@available(iOS 17.0, tvOS 17.0, macOS 14.0, *)
private struct MetalVariableBlur: ViewModifier {

  let startPoint: CGFloat
  let maxRadius: CGFloat

  /// Enough taps to avoid banding without making the effect expensive on an Apple TV.
  private let tapCount: Float = 24

  func body(content: Content) -> some View {
    content.visualEffect { view, proxy in
      view.layerEffect(
        ShaderLibrary.bundle(.module).variableBlur(
          .float2(proxy.size.width, proxy.size.height),
          .float(Float(startPoint)),
          .float(Float(maxRadius)),
          .float(tapCount)
        ),
        // The shader never samples further than the largest radius it applies.
        maxSampleOffset: CGSize(width: maxRadius, height: maxRadius)
      )
    }
  }
}
