//
//  MediaActionButtonStyle.swift
//  KinoPubUI
//
//  Rivulet-style hero action controls: fixed glass pill + matching circles.
//  Resting = translucent white + material; focused = solid white, content inverts
//  to black, gentle scale. Ported from Rivulet's HeroPillButton / HeroCircleButton
//  / FocusableActionButton so detail pages share one look across clients.
//

import SwiftUI

// MARK: - Metrics

public enum MediaActionMetrics {
#if os(tvOS)
  /// Minimum width for the Play / Resume pill. Watchlist and other labeled pills hug content.
  public static let playPillMinWidth: CGFloat = 250
  public static let buttonHeight: CGFloat = 66
  public static let iconPointSize: CGFloat = 22
  public static let circleIconPointSize: CGFloat = 24
  public static let labelFont = Font.system(size: 22, weight: .semibold)
  public static let progressWidth: CGFloat = 60
  public static let progressHeight: CGFloat = 3
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

// MARK: - Ghost style (ellipsis — no fill until focused)

/// Icon-only control with no resting chrome. Background + invert appear only on focus,
/// so it reads as a quiet overflow affordance next to the solid action pills/circles.
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

  /// On tvOS, focus lights the pill. Elsewhere the primary (Play) pill stays in the
  /// focused look permanently — that chrome is the platform's "primary" subtype.
  private var showsFocusedChrome: Bool {
#if os(tvOS)
    isFocused
#else
    isPrimary || isFocused
#endif
  }

  var body: some View {
    content
      .foregroundStyle(showsFocusedChrome ? Color.black : Color.white)
      .padding(.horizontal, MediaActionMetrics.pillHorizontalPadding)
      .frame(minWidth: minWidth, minHeight: MediaActionMetrics.buttonHeight)
      .frame(height: MediaActionMetrics.buttonHeight)
      .background {
        ZStack {
          Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(showsFocusedChrome ? 0 : 1)
          Capsule(style: .continuous)
            .fill(showsFocusedChrome ? Color.white : Color.white.opacity(0.2))
        }
      }
      .overlay {
        Capsule(style: .continuous)
          .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
          .opacity(showsFocusedChrome ? 0 : 1)
      }
      .clipShape(Capsule(style: .continuous))
      .scaleEffect(scale)
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showsFocusedChrome)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: isPressed)
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
            .fill(isFocused ? Color.white : Color.white.opacity(0.12))
        }
      }
      .overlay {
        Circle()
          .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
          .opacity(isFocused ? 0 : 1)
      }
      .clipShape(Circle())
      .scaleEffect(scale)
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: isPressed)
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

  var body: some View {
    content
      .foregroundStyle(isFocused ? Color.black : Color.white)
      .frame(width: MediaActionMetrics.buttonHeight, height: MediaActionMetrics.buttonHeight)
      .background {
        Circle()
          .fill(Color.white)
          .opacity(isFocused ? 1 : 0)
      }
      .clipShape(Circle())
      .scaleEffect(scale)
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isFocused)
      .animation(.spring(response: 0.15, dampingFraction: 0.9), value: isPressed)
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
          .frame(width: max(0, MediaActionMetrics.progressWidth * min(max(progress, 0), 1)),
                 height: MediaActionMetrics.progressHeight)
      }
  }

  private var trackColor: Color {
    inverted
      ? Color.black.opacity(0.2)
      : Color.white.opacity(0.25)
  }

  private var fillColor: Color {
    inverted ? Color.black.opacity(0.55) : Color.white.opacity(0.9)
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
