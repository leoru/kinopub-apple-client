//
//  MediaActionButtonStyle.swift
//  KinoPubUI
//
//  Hero action controls. These are the **system** button styles with a border shape,
//  and nothing else.
//
//  They used to be three hand-written `ButtonStyle`s: capsule and circle plates painted
//  by hand, a hairline stroke, `Color.white.opacity(0.22)` fills, black-on-white
//  inversion, `.onHover` state, drop shadows, and a `scaleEffect` focus lift with its
//  own spring. That is a reimplementation of `.borderedProminent` / `.bordered` that
//  drifts from the platform every release — and on tvOS it also meant the focus lift,
//  the specular highlight and the press feedback were ours to keep in step with a
//  system that already does all three. `AGENTS.md`:
//  custom chrome needs a named missing API, and there was none.
//
//  What is left here is the vocabulary (which control is the primary, which is a
//  secondary, which is a circle), the icon/label metrics, and the resume bar — the one
//  piece the system genuinely does not ship.
//

import SwiftUI

// MARK: - Metrics

public enum MediaActionMetrics {
#if os(tvOS)
  /// Floor for the Play label so the primary control keeps its weight next to a
  /// labelled Trailer button. Applied to the *label*: the button itself is system-drawn
  /// and hugs whatever it is given.
  public static let playPillMinWidth: CGFloat = 200
  public static let buttonHeight: CGFloat = 66
  public static let iconPointSize: CGFloat = 26
  public static let circleIconPointSize: CGFloat = 24
  public static let labelFont = TypeScale.actionLabel
  public static let progressWidth: CGFloat = 60
  public static let progressHeight: CGFloat = 5
  public static let contentSpacing: CGFloat = 12
  public static let rowSpacing: CGFloat = 16
#else
  public static let playPillMinWidth: CGFloat = 168
  public static let buttonHeight: CGFloat = 44
  public static let iconPointSize: CGFloat = 15
  public static let circleIconPointSize: CGFloat = 16
  public static let labelFont = TypeScale.actionLabel
  public static let progressWidth: CGFloat = 40
  public static let progressHeight: CGFloat = 3
  public static let contentSpacing: CGFloat = 8
  public static let rowSpacing: CGFloat = 12
#endif
}

// MARK: - Scaled icon glyphs

/// `.system(size:weight:)` for an SF Symbol glyph, but the size still tracks Dynamic
/// Type. Icons here are sized off the button's own geometry, not a text baseline, so a
/// text style would fit the wrong thing — this scales the exact point size instead, the
/// same way a semantic style would.
private struct ScaledIconFont: ViewModifier {
  @ScaledMetric private var size: CGFloat
  private let weight: Font.Weight

  init(size: CGFloat, weight: Font.Weight) {
    self._size = ScaledMetric(wrappedValue: size)
    self.weight = weight
  }

  func body(content: Content) -> some View {
    content.font(.system(size: size, weight: weight))
  }
}

public extension View {
  /// Apply to an `Image(systemName:)` glyph in place of `.font(.system(size:weight:))`.
  func mediaActionIconFont(size: CGFloat, weight: Font.Weight) -> some View {
    modifier(ScaledIconFont(size: size, weight: weight))
  }
}

// MARK: - System styles

public extension View {
  /// Play / Resume — the primary call to action.
  func mediaActionPlayPillStyle() -> some View {
    buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
#if !os(tvOS)
      .controlSize(.large)
#endif
  }

  /// A labelled secondary control (Trailer, Watchlist) — same capsule, quieter weight.
  func mediaActionPillStyle() -> some View {
    buttonStyle(.bordered)
      .buttonBorderShape(.capsule)
#if !os(tvOS)
      .controlSize(.large)
#endif
  }

  /// An icon-only secondary control. `.circle` is a real `ButtonBorderShape`, so the
  /// plate, its focus treatment and its press feedback are all the system's.
  func mediaActionCircleStyle() -> some View {
    buttonStyle(.bordered)
      .buttonBorderShape(.circle)
#if !os(tvOS)
      .controlSize(.large)
#endif
  }
}

// MARK: - Resume bar

/// Thin capsule track shown inside the Play control once playback has started. The one
/// piece with no system equivalent — and the only reason this file still draws anything.
///
/// Colours are **hierarchical styles, not literals**: inside a button label they resolve
/// against whatever foreground the current style and focus state established, so the bar
/// inverts with the button instead of guessing when the button turned white. The old
/// version hard-coded black-on-white and needed a `forceFocusedColors` flag to paper
/// over the cases where the guess was wrong.
public struct MediaActionProgressTrack: View {
  public var progress: Double

  public init(progress: Double) {
    self.progress = progress
  }

  public var body: some View {
    Capsule()
      .fill(.tertiary)
      .frame(width: MediaActionMetrics.progressWidth,
             height: MediaActionMetrics.progressHeight)
      .overlay(alignment: .leading) {
        Capsule()
          .fill(.primary)
          .frame(width: max(6, MediaActionMetrics.progressWidth * min(max(progress, 0), 1)),
                 height: MediaActionMetrics.progressHeight)
      }
  }
}

#Preview("Action chrome") {
  HStack(spacing: MediaActionMetrics.rowSpacing) {
    Button {} label: {
      HStack(spacing: MediaActionMetrics.contentSpacing) {
        Image(systemName: "play.fill")
          .mediaActionIconFont(size: MediaActionMetrics.iconPointSize, weight: .semibold)
        Text("Play")
          .font(MediaActionMetrics.labelFont)
      }
      .frame(minWidth: MediaActionMetrics.playPillMinWidth)
    }
    .mediaActionPlayPillStyle()

    Button {} label: {
      Label("Trailer", systemImage: "film")
        .font(MediaActionMetrics.labelFont)
    }
    .mediaActionPillStyle()

    Button {} label: {
      Image(systemName: "bookmark.fill")
        .mediaActionIconFont(size: MediaActionMetrics.circleIconPointSize, weight: .semibold)
    }
    .mediaActionCircleStyle()
  }
  .padding(32)
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .background(Color.black)
  .preferredColorScheme(.dark)
}
