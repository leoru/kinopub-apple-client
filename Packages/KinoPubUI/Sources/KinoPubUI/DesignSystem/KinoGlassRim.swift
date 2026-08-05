//
//  KinoGlassRim.swift
//  KinoPubUI
//

import SwiftUI

/// Cheap glass imitation: a hairline diagonal stroke on clipped artwork.
/// Not Liquid Glass — no backdrop sampling. Used on iOS/macOS card art and
/// cast portraits; tvOS keeps system focus chrome instead.
public extension View {
  func kinoGlassRim<S: InsettableShape>(in shape: S) -> some View {
    modifier(KinoGlassRimModifier(shape: shape))
  }
}

private struct KinoGlassRimModifier<S: InsettableShape>: ViewModifier {
  let shape: S

  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let rim = colorScheme == .dark ? Color.white : Color.black
    content.overlay {
      shape
        .strokeBorder(
          LinearGradient(
            colors: [rim.opacity(0.15), rim.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.5
        )
    }
  }
}
