#if os(tvOS)
//
//  TVUIKitCardText.swift
//  KinoPubUI
//
//  The two lines under a tvOS tile, for every TVUIKit cell that has them.
//
//  **Two lines, no more** (user decision, 2026-08-10). A wide tile has
//  `TVMediaItemContentConfiguration.text` / `.secondaryText` and nothing else; a poster
//  gets the same pair from `TVUIKitPosterCell`'s own labels, because `TVPosterView`'s
//  built-in title/subtitle reserve footer space that crops 2:3 art. Lockups and footer
//  views are deliberately not on the table yet — anything that does not fit these two
//  lines gets packed into them, not given a third.
//
//  Artwork stays clean. Only a badge, the progress bar, the duration chip and the
//  watch-status glyph are allowed over the image; metadata belongs underneath, where it
//  needs no scrim or blur to stay legible over a still.
//
//  The second line is built from the **same** `MediaCardDisplayPreferences` the SwiftUI
//  card reads, so the display settings that already existed keep working here instead of
//  tvOS quietly growing a fixed format of its own.
//

import Foundation

public enum TVUIKitCardText {

  /// The name. A title, or the episode designation when there is no title at all.
  public static func primary(for card: MediaCard) -> String? {
    if !card.title.isEmpty { return card.title }
    guard let overlay = card.overlayLabel, !overlay.isEmpty else { return nil }
    return overlay
  }

  /// Everything else, in one line, in the order it is useful: which episode this is,
  /// then what the title is like. Apple's own sample puts exactly this in
  /// `secondaryText` ("S1, E1"), so the shape is the platform's, not ours.
  ///
  /// Returns nil rather than an empty string — a tile with nothing to add must not
  /// reserve a blank second line.
  public static func secondary(for card: MediaCard) -> String? {
    var parts: [String] = []

    // "S2, E11" leads: it says *which* thing this is before saying what it is like.
    // Skipped when the title was empty, because then it is already the primary line.
    if !card.title.isEmpty, let overlay = card.overlayLabel, !overlay.isEmpty {
      parts.append(overlay)
    }
    if MediaCardDisplayPreferences.showOriginalTitle,
       let original = card.subtitle, !original.isEmpty, original != card.title {
      parts.append(original)
    }
    if MediaCardDisplayPreferences.showYear, let year = card.year {
      parts.append(String(year))
    }
    if MediaCardDisplayPreferences.showGenre, let genre = card.genreLine, !genre.isEmpty {
      parts.append(genre)
    }
    if MediaCardDisplayPreferences.showCountry, let country = card.countryLine, !country.isEmpty {
      parts.append(country)
    }

    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}
#endif
