//
//  MediaActionButtonStyle.swift
//  KinoPubUI
//
//  Hero action controls: primary white pill + translucent circular secondaries.
//  Matches Apple TV (prominent Play, quieter circles) — not Liquid Glass overlays.
//  Resting primary = solid white / black content; focused = scale + same invert.
//  Secondary circles = translucent plate at rest, solid white when focused.
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
  /// Primary CTA (Play): solid white at rest — Apple TV prominence, not glass.
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

  /// Primary is always the prominent (white) look. Secondary lights on focus / hover.
  private var showsProminentChrome: Bool {
    if isPrimary { return true }
#if os(tvOS)
    return isFocused
#else
    return isFocused || isHovered
#endif
  }

  var body: some View {
    content
      .foregroundStyle(showsProminentChrome ? Color.black : Color.white)
      .padding(.horizontal, MediaActionMetrics.pillHorizontalPadding)
      .frame(minWidth: minWidth, minHeight: MediaActionMetrics.buttonHeight)
      .background {
        Capsule(style: .continuous)
          .fill(fillColor)
      }
      .overlay {
        Capsule(style: .continuous)
          .strokeBorder(Color.white.opacity(0.35), lineWidth: Metrics.hairline)
          .opacity(showsProminentChrome ? 0 : 1)
      }
      .clipShape(Capsule(style: .continuous))
      .shadow(color: .black.opacity(showsProminentChrome ? 0.35 : 0.2), radius: 8, y: 4)
      .scaleEffect(scale)
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showsProminentChrome)
      .animation(.easeOut(duration: 0.15), value: isHovered)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: isPressed)
#if !os(tvOS)
      .onHover { isHovered = $0 }
      .pointingHandCursorOnHover()
#endif
  }

  private var fillColor: Color {
    if showsProminentChrome { return Color.white }
    // Secondary labeled pill: translucent, not glass material.
    return Color.white.opacity(0.22)
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

  private var showsProminentChrome: Bool {
#if os(tvOS)
    isFocused
#else
    isFocused || isHovered
#endif
  }

  var body: some View {
    content
      .foregroundStyle(showsProminentChrome ? Color.black : Color.white)
      .frame(width: MediaActionMetrics.buttonHeight, height: MediaActionMetrics.buttonHeight)
      .background {
        Circle()
          .fill(fillColor)
      }
      .overlay {
        Circle()
          .strokeBorder(Color.white.opacity(0.35), lineWidth: Metrics.hairline)
          .opacity(showsProminentChrome ? 0 : 1)
      }
      .clipShape(Circle())
      .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
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
    if showsProminentChrome { return Color.white }
    return Color.white.opacity(0.22)
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

  private var showsSecondaryPlate: Bool {
#if os(tvOS)
    isFocused
#else
    isHovered || isFocused
#endif
  }

  var body: some View {
    content
      .foregroundStyle(showsSecondaryPlate && isFocused ? Color.black : Color.white)
      .frame(width: MediaActionMetrics.buttonHeight, height: MediaActionMetrics.buttonHeight)
      .contentShape(Circle())
      .background {
        Circle()
          .fill(isFocused ? Color.white : Color.white.opacity(showsSecondaryPlate ? 0.22 : 0))
      }
      .overlay {
        if showsSecondaryPlate && !isFocused {
          Circle()
            .strokeBorder(Color.white.opacity(0.35), lineWidth: Metrics.hairline)
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
  /// When true (Play primary), use the inverted track colours for the white pill.
  public var forceFocusedColors: Bool
  @Environment(\.isFocused) private var isFocused

  public init(progress: Double, forceFocusedColors: Bool = false) {
    self.progress = progress
    self.forceFocusedColors = forceFocusedColors
  }

  private var inverted: Bool {
    // Primary play pill is always white → dark track.
    forceFocusedColors || isFocused
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
  /// Play / Resume pill — primary CTA. Solid white at rest (Apple TV prominence).
  func mediaActionPlayPillStyle() -> some View {
    buttonStyle(MediaActionPillStyle(minWidth: MediaActionMetrics.playPillMinWidth, isPrimary: true))
  }

  /// Labeled secondary pill (Watchlist) — hugs its content, translucent resting plate.
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
