//
//  MediaActionButtonStyle.swift
//  KinoPubUI
//
//  Rivulet-style hero action controls: fixed glass pill + matching circles.
//  Resting = translucent white + material; focused = solid white, content inverts
//  to black, gentle scale. Ported from Rivulet's HeroPillButton / HeroCircleButton
//  / FocusableActionButton so detail pages share one look across clients.
//
//  Non-tvOS pointer: secondary controls lighten slightly on hover (no white invert —
//  that stays focus/primary-only), press scales immediately on touch-down, and the
//  ghost ellipsis picks up the same resting secondary plate so it is hittable.
//

import SwiftUI

// MARK: - Metrics

public enum MediaActionMetrics {
#if os(tvOS)
  /// Minimum width for the Play / Resume pill. Watchlist and other labeled pills hug content.
  public static let playPillMinWidth: CGFloat = 200
  public static let buttonHeight: CGFloat = 66
  public static let iconPointSize: CGFloat = 26
  public static let circleIconPointSize: CGFloat = 24
  public static let labelFont = Font.system(size: 22, weight: .semibold)
  public static let progressWidth: CGFloat = 60
  public static let progressHeight: CGFloat = 5
  public static let contentSpacing: CGFloat = 12
  public static let pillHorizontalPadding: CGFloat = 28
  public static let rowSpacing: CGFloat = 16
  public static let focusScale: CGFloat = 1.08
#else
  public static let playPillMinWidth: CGFloat = 168
  public static let buttonHeight: CGFloat = 44
  public static let iconPointSize: CGFloat = 15
  public static let circleIconPointSize: CGFloat = 16
  public static let labelFont = Font.system(size: 15, weight: .semibold)
  public static let progressWidth: CGFloat = 40
  public static let progressHeight: CGFloat = 3
  public static let contentSpacing: CGFloat = 8
  public static let pillHorizontalPadding: CGFloat = 18
  public static let rowSpacing: CGFloat = 12
  public static let focusScale: CGFloat = 1.04
#endif

  public static var cornerRadius: CGFloat { buttonHeight / 2 }
}

// MARK: - Pill style (Play / Resume / Watchlist)

public struct MediaActionPillStyle: ButtonStyle {
  /// When set, the pill won't shrink below this width (Play). `nil` = hug content (Watchlist).
  public var minWidth: CGFloat?
  /// Primary CTA (Play): on non-tvOS this locks the focused look — solid white fill,
  /// inverted content — because there's no focus engine; the focused chrome *is* the
  /// primary subtype. On tvOS focus still drives the transition.
  public var isPrimary: Bool

  public init(minWidth: CGFloat? = nil, isPrimary: Bool = false) {
    self.minWidth = minWidth
    self.isPrimary = isPrimary
  }

  public func makeBody(configuration: Configuration) -> some View {
    MediaActionPillChrome(
      minWidth: minWidth,
      isPrimary: isPrimary,
      isPressed: configuration.isPressed
    ) {
      configuration.label
    }
  }
}

// MARK: - Circle style (watched / bookmark)

public struct MediaActionCircleStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    MediaActionCircleChrome(isPressed: configuration.isPressed) {
      configuration.label
    }
  }
}

// MARK: - Ghost style (ellipsis — no fill until focused / hovered)

/// Icon-only control with no resting chrome. Background appears on focus (tvOS) or
/// hover (pointer platforms), matching the secondary circle so the hit target is obvious.
public struct MediaActionGhostStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    MediaActionGhostChrome(isPressed: configuration.isPressed) {
      configuration.label
    }
  }
}

// MARK: - Pill chrome

private struct MediaActionPillChrome<Content: View>: View {
  let minWidth: CGFloat?
  let isPrimary: Bool
  let isPressed: Bool
  @ViewBuilder let content: Content
  @Environment(\.isFocused) private var isFocused
  @State private var isHovered = false

  /// On tvOS, focus lights the pill. Elsewhere the primary (Play) pill stays in the
  /// focused look permanently — that chrome is the platform's "primary" subtype.
  private var showsFocusedChrome: Bool {
#if os(tvOS)
    isFocused
#else
    isPrimary || isFocused
#endif
  }

  private var showsHoverChrome: Bool {
#if os(tvOS)
    false
#else
    !isPrimary && isHovered && !showsFocusedChrome
#endif
  }

  var body: some View {
    content
      .foregroundStyle(isFocused ? Color.black : isHovered ? Color.black : Color.white)
      .padding(.horizontal, MediaActionMetrics.pillHorizontalPadding)
      .frame(minWidth: minWidth, minHeight: MediaActionMetrics.buttonHeight)
      .frame(height: MediaActionMetrics.buttonHeight)
      .background {
        ZStack {
          Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(isFocused || isPrimary ? 0 : 1)
          Capsule(style: .continuous)
            .fill(isFocused ? Color.white : isHovered ? Color.white : fillColor)
        }
      }
      .overlay {
        Capsule(style: .continuous)
          .strokeBorder(Color.white.opacity(showsHoverChrome ? 0.5 : 0.5), lineWidth: 0.5)
          .opacity(showsFocusedChrome ? 0 : 1)
      }
      .clipShape(Capsule(style: .continuous))
      .shadow(color: .black.opacity(isFocused ? 0.4 : isHovered && isPrimary ? 0.6 : 0), radius: isHovered ? 14 : 8, y: isHovered ? 10 : 4)
      .scaleEffect(scale)
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showsFocusedChrome)
      .animation(.easeOut(duration: 0.15), value: isHovered)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: isPressed)
#if !os(tvOS)
      .onHover { isHovered = $0 }
      .pointingHandCursorOnHover()
#endif
  }

  private var fillColor: Color {
    if showsFocusedChrome { return Color.black.opacity(0.5) }
    if showsHoverChrome { return Color.black.opacity(0.3) }
    return Color.black.opacity(0.5)
  }

  private var scale: CGFloat {
#if os(tvOS)
    let focused = isFocused ? MediaActionMetrics.focusScale : 1
#else
    let focused: CGFloat = 1
#endif
    return isPressed ? focused * 0.95 : focused
  }
}

// MARK: - Circle chrome

private struct MediaActionCircleChrome<Content: View>: View {
  let isPressed: Bool
  @ViewBuilder let content: Content
  @Environment(\.isFocused) private var isFocused
  @State private var isHovered = false

  private var showsHoverChrome: Bool {
#if os(tvOS)
    true
#else
    isHovered && !isFocused
#endif
  }

  var body: some View {
    content
      .foregroundStyle(isFocused ? Color.black : Color.white)
      .frame(width: MediaActionMetrics.buttonHeight, height: MediaActionMetrics.buttonHeight)
      .background {
        ZStack {
          Circle()
            .fill(.ultraThinMaterial)
            .opacity(isFocused ? 0 : 1)
          Circle()
            .fill(fillColor)
        }
      }
      .overlay {
        Circle()
          .strokeBorder(Color.white.opacity(showsHoverChrome ? 0.5 : 0.5), lineWidth: 0.5)
          .opacity(isFocused ? 0 : 1)
      }
      .clipShape(Circle())
      .shadow(color: .black.opacity(showsHoverChrome ? 0.25 : 0.25), radius: 8, y: 2)
      .scaleEffect(scale)
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
      .animation(.easeOut(duration: 0.15), value: isHovered)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: isPressed)
#if !os(tvOS)
      .onHover { isHovered = $0 }
      .pointingHandCursorOnHover()
#endif
  }

  private var fillColor: Color {
    if isFocused { return Color.white }
    if showsHoverChrome { return Color.black.opacity(0.4) }
    return Color.black.opacity(0.3)
  }

  private var scale: CGFloat {
    let focused = isFocused ? MediaActionMetrics.focusScale : 1
    return isPressed ? focused * 0.95 : focused
  }
}

// MARK: - Ghost chrome

private struct MediaActionGhostChrome<Content: View>: View {
  let isPressed: Bool
  @ViewBuilder let content: Content
  @Environment(\.isFocused) private var isFocused
  @State private var isHovered = false

  /// Hover uses the secondary circle plate — not the solid white focus invert.
  private var showsSecondaryPlate: Bool {
#if os(tvOS)
    false
#else
    isHovered && !isFocused
#endif
  }

  var body: some View {
    content
      .foregroundStyle(Color.white)
      .frame(width: MediaActionMetrics.buttonHeight, height: MediaActionMetrics.buttonHeight)
      .contentShape(Circle())
      .background {
        ZStack {
          if showsSecondaryPlate {
            Circle()
              .fill(.ultraThinMaterial)
            Circle()
              .fill(Color.black.opacity(0.5))
          }
          Circle()
            .fill(Color.black.opacity(0.15))
            .opacity(isFocused || isHovered ? 1 : 0)
        }
      }
      .overlay {
        if showsSecondaryPlate {
          Circle()
            .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
        }
      }
      .clipShape(Circle())
      .scaleEffect(scale)
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
      .animation(.easeOut(duration: 0.15), value: isHovered)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: isPressed)
#if !os(tvOS)
      .onHover { isHovered = $0 }
      .pointingHandCursorOnHover()
#endif
  }

  private var scale: CGFloat {
    let focused = isFocused ? MediaActionMetrics.focusScale : 1
    return isPressed ? focused * 0.95 : focused
  }
}

// MARK: - Progress track (invert-friendly)

/// Thin capsule track used inside the play pill when playback has already started.
public struct MediaActionProgressTrack: View {
  public var progress: Double
  /// When true (Play primary on non-tvOS), use the inverted track colours even
  /// without focus — matching the primary pill chrome.
  public var forceFocusedColors: Bool
  @Environment(\.isFocused) private var isFocused

  public init(progress: Double, forceFocusedColors: Bool = false) {
    self.progress = progress
    self.forceFocusedColors = forceFocusedColors
  }

  private var inverted: Bool {
#if os(tvOS)
    isFocused
#else
    forceFocusedColors || isFocused
#endif
  }

  public var body: some View {
    Capsule()
      .fill(trackColor)
      .frame(width: MediaActionMetrics.progressWidth,
             height: MediaActionMetrics.progressHeight)
      .overlay(alignment: .leading) {
        Capsule()
          .fill(fillColor)
          .frame(width: max(6, MediaActionMetrics.progressWidth * min(max(progress, 0), 1)),
                 height: MediaActionMetrics.progressHeight)
      }
  }

  private var trackColor: Color {
    inverted
      ? Color.black.opacity(0.3)
      : Color.white.opacity(0.25)
  }

  private var fillColor: Color {
    inverted ? Color.black.opacity(0.55) : Color.white.opacity(1)
  }
}

// MARK: - Convenience modifiers

public extension View {
  /// Play / Resume pill — primary CTA. Min width floor; on non-tvOS uses the focused
  /// (solid white) look as its resting primary subtype.
  func mediaActionPlayPillStyle() -> some View {
    buttonStyle(MediaActionPillStyle(minWidth: MediaActionMetrics.playPillMinWidth, isPrimary: true))
  }

  /// Labeled secondary pill (Watchlist) — hugs its content, no minimum width.
  func mediaActionPillStyle() -> some View {
    buttonStyle(MediaActionPillStyle(minWidth: nil, isPrimary: false))
  }

  func mediaActionCircleStyle() -> some View {
    buttonStyle(MediaActionCircleStyle())
  }

  func mediaActionGhostStyle() -> some View {
    buttonStyle(MediaActionGhostStyle())
  }
}
