//
//  ProgressiveBlur.swift
//  KinoPubUI
//
//  Private `CAFilter` `variableBlur` overlay (jtrivedi / nikstar pattern).
//  Blurs whatever sits behind this view in the window — place it on top of
//  static artwork in a ZStack. Platform rules (D1): OK over static images;
//  skip while video is showing on tvOS/macOS; OK over video on iOS/iPadOS.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import QuartzCore

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum ProgressiveBlurDirection: Sendable {
  /// Sharp at the top, blurred toward the bottom (hero / card footers).
  case blurredBottomClearTop
  /// Blurred at the top, clear toward the bottom (nav-style washes).
  case blurredTopClearBottom
}

/// Overlay that applies a Music/Journal-style variable blur to content behind it.
///
/// Usage:
/// ```swift
/// ZStack {
///   artwork
///   ProgressiveBlur(startPoint: 0.35, maxRadius: 40)
///   labels
/// }
/// ```
public struct ProgressiveBlur: View {
  private let startPoint: CGFloat
  private let maxRadius: CGFloat
  private let direction: ProgressiveBlurDirection
  /// When false the overlay is omitted (e.g. trailer playing on tvOS/macOS).
  private let isEnabled: Bool

  /// - Parameters:
  ///   - startPoint: where blur begins along the gradient axis, 0…1.
  ///     For `.blurredBottomClearTop`, 0 = top (blur sooner), closer to 1 = blur only near bottom.
  ///   - maxRadius: blur radius where the mask is fully opaque.
  ///   - layers: unused — kept for call-site compatibility.
  ///   - direction: gradient orientation.
  ///   - isEnabled: pass `false` to disable (no blur over video on tvOS/macOS).
  public init(startPoint: CGFloat = 0.4,
              maxRadius: CGFloat = 40,
              layers: Int = 4,
              direction: ProgressiveBlurDirection = .blurredBottomClearTop,
              isEnabled: Bool = true) {
    self.startPoint = startPoint
    self.maxRadius = maxRadius
    self.direction = direction
    self.isEnabled = isEnabled
  }

  public var body: some View {
    Group {
      if isEnabled {
        VariableBlurRepresentable(
          maxBlurRadius: maxRadius,
          startOffset: startPoint,
          direction: direction
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
    }
  }
}

// MARK: - Representable

#if canImport(UIKit)
private struct VariableBlurRepresentable: UIViewRepresentable {
  var maxBlurRadius: CGFloat
  var startOffset: CGFloat
  var direction: ProgressiveBlurDirection

  func makeUIView(context: Context) -> VariableBlurPlatformView {
    VariableBlurPlatformView(
      maxBlurRadius: maxBlurRadius,
      startOffset: startOffset,
      direction: direction
    )
  }

  func updateUIView(_ uiView: VariableBlurPlatformView, context: Context) {}
}

private final class VariableBlurPlatformView: UIVisualEffectView {
  init(maxBlurRadius: CGFloat, startOffset: CGFloat, direction: ProgressiveBlurDirection) {
    super.init(effect: UIBlurEffect(style: .regular))
    applyVariableBlur(maxBlurRadius: maxBlurRadius, startOffset: startOffset, direction: direction)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func didMoveToWindow() {
    guard let window, let backdropLayer = subviews.first?.layer else { return }
    backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    // Avoid UIVisualEffectView's traitCollectionDidChange crash with custom filters.
  }
}

#elseif canImport(AppKit)
private struct VariableBlurRepresentable: NSViewRepresentable {
  var maxBlurRadius: CGFloat
  var startOffset: CGFloat
  var direction: ProgressiveBlurDirection

  func makeNSView(context: Context) -> VariableBlurPlatformView {
    VariableBlurPlatformView(
      maxBlurRadius: maxBlurRadius,
      startOffset: startOffset,
      direction: direction
    )
  }

  func updateNSView(_ nsView: VariableBlurPlatformView, context: Context) {}
}

private final class VariableBlurPlatformView: NSVisualEffectView {
  init(maxBlurRadius: CGFloat, startOffset: CGFloat, direction: ProgressiveBlurDirection) {
    super.init(frame: .zero)
    material = .fullScreenUI
    blendingMode = .behindWindow
    state = .active
    applyVariableBlur(maxBlurRadius: maxBlurRadius, startOffset: startOffset, direction: direction)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
#endif

// MARK: - Shared filter setup

#if canImport(UIKit) || canImport(AppKit)
private extension VariableBlurPlatformView {
  func applyVariableBlur(maxBlurRadius: CGFloat,
                         startOffset: CGFloat,
                         direction: ProgressiveBlurDirection) {
    // Obfuscated private class / selector (personal project → private API OK).
    let className = String("retliFAC".reversed())
    guard let filterClass = NSClassFromString(className) as? NSObject.Type else { return }
    let selectorName = String(":epyThtiWretlif".reversed())
    guard let filter = filterClass.perform(
      NSSelectorFromString(selectorName),
      with: "variableBlur"
    )?.takeUnretainedValue() as? NSObject else { return }

    let mask = makeGradientMask(startOffset: startOffset, direction: direction)
    filter.setValue(maxBlurRadius, forKey: "inputRadius")
    filter.setValue(mask, forKey: "inputMaskImage")
    filter.setValue(true, forKey: "inputNormalizeEdges")

#if canImport(UIKit)
    let backdropLayer = subviews.first?.layer
    backdropLayer?.filters = [filter]
    for subview in subviews.dropFirst() {
      subview.alpha = 0
    }
#elseif canImport(AppKit)
    wantsLayer = true
    layer?.filters = [filter]
#endif
  }
}

private func makeGradientMask(width: CGFloat = 100,
                              height: CGFloat = 100,
                              startOffset: CGFloat,
                              direction: ProgressiveBlurDirection) -> CGImage? {
  let filter = CIFilter.linearGradient()
  filter.color0 = CIColor.black
  filter.color1 = CIColor.clear

  let clampedStart = min(max(startOffset, 0), 0.95)
  switch direction {
  case .blurredBottomClearTop:
    // Clear (no blur) above startOffset; full blur at the bottom.
    filter.point0 = CGPoint(x: 0, y: 0)
    filter.point1 = CGPoint(x: 0, y: height * (1 - clampedStart))
  case .blurredTopClearBottom:
    filter.point0 = CGPoint(x: 0, y: height)
    filter.point1 = CGPoint(x: 0, y: height * clampedStart)
  }

  guard let output = filter.outputImage else { return nil }
  return CIContext().createCGImage(output, from: CGRect(x: 0, y: 0, width: width, height: height))
}
#endif
