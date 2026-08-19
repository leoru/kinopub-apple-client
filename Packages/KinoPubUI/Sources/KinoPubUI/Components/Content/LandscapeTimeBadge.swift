//
//  LandscapeTimeBadge.swift
//  KinoPubUI
//
//  Apple-style landscape still time chip: play + duration, play + time left,
//  or checkmark + duration when finished.
//

import SwiftUI
import KinoPubBackend

/// Watch-state chip for landscape cards (Continue Watching, History, etc.).
public struct LandscapeTimeBadge: View {
  public enum Kind: Equatable {
    case unwatched(total: String)
    case inProgress(remaining: String)
    case watched(total: String)
  }

  public let kind: Kind

  public init(kind: Kind) {
    self.kind = kind
  }

  /// Builds a badge from a card that already classified through `WatchProgress`.
  ///
  /// `progress` is `resumeFraction` (nil unless in-progress). Do not pass a raw
  /// `time / duration` and expect this init to recover the credits window — 0.95
  /// of a two-hour title is six minutes left; `WatchProgress` finishes at three.
  public init?(durationSeconds: Int?, progress: Double?, isWatched: Bool) {
    guard let durationSeconds, durationSeconds >= 60,
          let total = Self.compactLabel(seconds: durationSeconds) else {
      return nil
    }
    if isWatched {
      self.kind = .watched(total: total)
      return
    }
    if let fraction = progress {
      let remaining = Int(Double(durationSeconds) * (1 - min(max(fraction, 0), 1)))
      if let label = Self.compactLabel(seconds: max(remaining, 60)) {
        self.kind = .inProgress(remaining: label)
        return
      }
    }
    self.kind = .unwatched(total: total)
  }

  public var body: some View {
    HStack(spacing: 4) {
      if let iconName {
        Image(systemName: iconName)
          .font(.system(size: 9, weight: .bold))
      }
      Text(label)
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
    }
    .foregroundStyle(isWatchedStyle ? Color.black.opacity(0.85) : Color.white)
    .padding(.horizontal, 7)
    .padding(.vertical, 4)
    .background(pillFill, in: Capsule(style: .continuous))
    .accessibilityLabel(Text(accessibilityLabel))
  }

  private var isWatchedStyle: Bool {
    if case .watched = kind { return true }
    return false
  }

  /// Nil draws the chip as bare time. Focus and pointer platforms already put a play
  /// glyph in the middle of the still while the card is focused / hovered, so the chip
  /// repeating it there is one glyph too many; touch has no such state and keeps it.
  private var iconName: String? {
    switch kind {
    case .watched:
      return "checkmark"
    case .unwatched, .inProgress:
#if os(tvOS) || os(macOS)
      return nil
#else
      return "play.fill"
#endif
    }
  }

  private var label: String {
    switch kind {
    case .unwatched(let total), .watched(let total):
      return total
    case .inProgress(let remaining):
      return String(format: String(localized: "%@ left"), remaining)
    }
  }

  private var accessibilityLabel: String {
    switch kind {
    case .unwatched(let total):
      return total
    case .watched(let total):
      return "\(String(localized: "Watched")), \(total)"
    case .inProgress(let remaining):
      return String(format: String(localized: "%@ left"), remaining)
    }
  }

  private var pillFill: Color {
    isWatchedStyle
      ? Color.white.opacity(0.92)
      : Color.black.opacity(0.55)
  }

  private static func compactLabel(seconds: Int) -> String? {
    let label = Duration.compact(seconds: seconds)
    return label.isEmpty ? nil : label
  }
}
