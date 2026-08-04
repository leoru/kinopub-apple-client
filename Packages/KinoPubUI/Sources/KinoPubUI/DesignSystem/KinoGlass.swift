//
//  KinoGlass.swift
//  KinoPubUI
//

import SwiftUI

/// The **only** place `glassEffect` is written. Call sites use `kinoGlass` /
/// `kinoPlayerGlass` so tint conventions, accessibility degradation, and the
/// low-power Apple TV substitute all live in one file. Every Apple target is on
/// the 26 baseline, so no availability branching is needed.
///
/// The system button styles — `.buttonStyle(.glass)` / `.glassProminent` — are a
/// separate, fully system-owned path. They degrade on their own and deliberately
/// do **not** route through here.
public extension View {
  /// Liquid Glass over static content: chrome, chips, floating panels.
  func kinoGlass(in shape: some Shape,
                 tint: Color? = nil,
                 interactive: Bool = false) -> some View {
    modifier(KinoGlassModifier(shape: shape,
                              tint: tint,
                              interactive: interactive,
                              overVideo: false))
  }

  /// Glass for surfaces drawn over **live video** — player HUD, controls, notices.
  ///
  /// Backdrop-sampling effects make the render server re-sample and re-blur the
  /// covered video region on every video frame. A12-class Apple TVs pay for that
  /// as a visible spike whenever the overlay is up, so those boxes get a
  /// non-sampling opaque fill instead.
  func kinoPlayerGlass(in shape: some Shape, tint: Color? = nil) -> some View {
    modifier(KinoGlassModifier(shape: shape,
                              tint: tint,
                              interactive: false,
                              overVideo: true))
  }
}

private struct KinoGlassModifier<S: Shape>: ViewModifier {
  let shape: S
  let tint: Color?
  let interactive: Bool
  let overVideo: Bool

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast

  /// Reduce Transparency and Increase Contrast both mean "stop sampling the
  /// backdrop"; over video we add the hardware check on top.
  private var mustNotSample: Bool {
    if reduceTransparency || contrast == .increased { return true }
    return overVideo && DevicePower.isLowPowerAppleTV
  }

  private var glass: Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
  }

  @ViewBuilder
  func body(content: Content) -> some View {
    if mustNotSample {
      content.background(shape.fill(Color.KinoPub.glassSubstitute))
    } else {
      content.glassEffect(glass, in: shape)
    }
  }
}
