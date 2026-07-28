//
//  ProgressiveBlur.swift
//
//

import Foundation
import SwiftUI

/// Blurs a view progressively down its height: sharp at the top, fully blurred at the
/// bottom. Uses a Metal layer effect (a genuine variable-radius blur).
public struct ProgressiveBlur<Content: View>: View {

  private let content: Content
  private let startPoint: CGFloat
  private let maxRadius: CGFloat

  /// - Parameters:
  ///   - startPoint: where the blur begins, 0 (top) to 1 (bottom).
  ///   - maxRadius: blur radius at the very bottom.
  ///   - layers: unused — kept for call-site compatibility until Phase 2d deletes this type.
  public init(startPoint: CGFloat = 0.4,
              maxRadius: CGFloat = 40,
              layers: Int = 4,
              @ViewBuilder content: () -> Content) {
    self.content = content()
    self.startPoint = startPoint
    self.maxRadius = maxRadius
  }

  public var body: some View {
    content.modifier(MetalVariableBlur(startPoint: startPoint, maxRadius: maxRadius))
  }
}

/// Drives `VariableBlur.metal`. `visualEffect` hands over the resolved size without
/// wrapping the content in a `GeometryReader`, which would change its layout.
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
