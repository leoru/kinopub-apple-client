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
///
/// `kinoGlassGroup` is the same rule applied to `GlassEffectContainer`: call sites
/// group sibling `kinoGlass` / `kinoPlayerGlass` surfaces through it rather than
/// writing `GlassEffectContainer` inline, so the "no raw glass API at call sites"
/// rule holds for grouping too. Reach for it only where two or more of those
/// surfaces actually sit next to each other — most of the app's chrome (hero
/// action row, `.buttonStyle(.glass)` buttons) isn't `kinoGlass` at all, and
/// wrapping non-glass content in a container does nothing.
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

/// Groups sibling `kinoGlass` / `kinoPlayerGlass` surfaces into one `GlassEffectContainer`
/// so the system renders them in a single pass instead of re-sampling the backdrop once
/// per surface. Only worth reaching for where two or more such surfaces are actually
/// adjacent — a container around a single glass view, or around non-glass content, does
/// nothing.
///
/// `spacing` must stay at or below the surrounding stack's own spacing: a container
/// spacing *larger* than the stack's makes the glass shapes blend into each other at
/// rest, which is only correct when merging is the intent. `nil` (the default) uses the
/// system's own default spacing.
public func kinoGlassGroup<Content: View>(spacing: CGFloat? = nil,
                                          @ViewBuilder content: () -> Content) -> some View {
  GlassEffectContainer(spacing: spacing, content: content)
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
