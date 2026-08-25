//
//  SubtitleRenditions.swift
//
//

import Foundation

/// One subtitle rendition as the player sees it, reduced to what matching needs.
///
/// A protocol rather than `AVMediaSelectionOption`, for the same reason `AudioRendition`
/// is one: the matching rules are the part with sharp edges, and they are worth testing
/// without an asset, a network and a simulator. `AVFoundation` conforms to this in the app.
public protocol SubtitleRendition {
  var renditionLanguageCode: String { get }
  var isForcedRendition: Bool { get }
}

/// Bridging between what `TrackResolver` decides — a `SubtitleTrack` built from the API's
/// list — and what the system player can actually select.
///
/// Off tvOS the viewer's subtitles are the master's own `SUBTITLES` renditions, which are
/// kino.pub's WebVTT copies of the same sidecar SRTs the API lists. There is no id in
/// common, so the pairing is **language plus position within that language** — the same
/// pair `SubtitleTrack.ordinal` already exists for, because sidecar URLs change between
/// two episodes of one season and a remembered choice has to survive that.
///
/// **The assumption is that a master lists a language's subtitle renditions in the order
/// the API lists them.** It holds for every kino.pub master looked at so far and is what
/// the ordinal means on the API side; when it does not, the fallbacks below still land on
/// the right *language*, which is the half a viewer notices.
public enum SubtitleRenditions {

  /// The rendition carrying `track`, or `nil` when this master offers nothing in its
  /// language — in which case the honest answer is no subtitles rather than a wrong line.
  public static func rendition<R: SubtitleRendition>(for track: SubtitleTrack,
                                                     in renditions: [R]) -> R? {
    let key = SubtitleTracks.languageKey(track.lang)
    let sameLanguage = renditions.filter {
      SubtitleTracks.languageKey($0.renditionLanguageCode) == key
    }
    guard !sameLanguage.isEmpty else { return nil }
    if sameLanguage.indices.contains(track.ordinal) {
      return sameLanguage[track.ordinal]
    }
    // Forced renditions are signage, never what "Russian subtitles" means — so when the
    // position is gone, the first non-forced one is the better guess.
    return sameLanguage.first { !$0.isForcedRendition } ?? sameLanguage.first
  }
}
