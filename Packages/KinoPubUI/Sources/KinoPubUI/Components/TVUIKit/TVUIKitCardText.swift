#if os(tvOS)
//
//  TVUIKitCardText.swift
//  KinoPubUI
//
//  The single line under a tvOS tile.
//
//  **One label** (user decision, 2026-08-11, reverting the two-line attempt of the day
//  before): `configuration.secondaryText` did not render on screen, so the second line
//  bought nothing and cost a wider tile. Treat the tile as having one line and pack what
//  matters into it. Everything else — year, country, genre — waits for a real decision
//  about where card metadata lives, not for another subtitle experiment.
//
//  No dates down here either: an announced episode says so in its top-corner badge, and
//  repeating it under the artwork is the same fact twice.
//

import Foundation

public enum TVUIKitCardText {

  /// Continue Watching and history: which episode, then which episode it *is*.
  /// `S2 E4 • Episode Name`, and just the title when there is no episode context.
  public static func caption(for card: MediaCard) -> String? {
    let title = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let overlay = card.overlayLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
          !overlay.isEmpty else {
      return title.isEmpty ? nil : title
    }
    return title.isEmpty ? overlay : "\(overlay) • \(title)"
  }

  /// An episode inside a season rail, where the season is already named by the tab
  /// above: `7. "Episode Name"`, or a bare `7.` when the name is unknown.
  public static func episodeCaption(number: Int, name: String?) -> String {
    let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "\(number)." : "\(number). \"\(trimmed)\""
  }
}
#endif
