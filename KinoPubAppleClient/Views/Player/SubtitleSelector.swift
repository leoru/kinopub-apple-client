//
//  SubtitleSelector.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

/// Which tracks a player opens with: the choice made last time on this title, or the
/// defaults from Profile → Playback when there is none.
enum SubtitleSelector {

  struct Selection: Equatable {
    var primary: SubtitleTrack?
    var secondary: SubtitleTrack?

    var isOff: Bool { primary == nil && secondary == nil }
  }

  static func tracks(in subtitles: [Subtitle]) -> [SubtitleTrack] {
    SubtitleTracks.catalog(subtitles)
  }

  /// A remembered choice wins over the defaults, and "subtitles off" is a choice —
  /// but a remembered language the item no longer offers falls back rather than
  /// leaving the screen bare.
  static func selection(in tracks: [SubtitleTrack],
                        remembered: SubtitleChoice?,
                        preferEnglish: Bool = SubtitlePreferences.preferEnglishSubtitles,
                        preferNonCC: Bool = SubtitlePreferences.preferNonCCSubtitles,
                        dualEnabled: Bool = SubtitlePreferences.dualSubtitlesEnabled,
                        secondLanguage: String = SubtitlePreferences.secondSubtitleLanguage) -> Selection {
    if let remembered {
      let primary = remembered.primary.flatMap { SubtitleTracks.resolve($0, in: tracks) }
      let secondary = remembered.secondary.flatMap { SubtitleTracks.resolve($0, in: tracks) }
      if remembered.isEmpty || primary != nil || secondary != nil {
        return normalized(Selection(primary: primary, secondary: secondary))
      }
    }

    let primary = preferEnglish
      ? SubtitleTracks.preferred(language: "en", in: tracks, preferNonCC: preferNonCC)
      : nil
    let secondary = dualEnabled
      ? SubtitleTracks.preferred(language: secondLanguage, in: tracks, preferNonCC: preferNonCC)
      : nil
    return normalized(Selection(primary: primary, secondary: secondary))
  }

  /// One track can't be both lines, and a second line without a first is just a first.
  private static func normalized(_ selection: Selection) -> Selection {
    var selection = selection
    if let primary = selection.primary, selection.secondary == primary {
      selection.secondary = nil
    }
    if selection.primary == nil, let secondary = selection.secondary {
      selection.primary = secondary
      selection.secondary = nil
    }
    return selection
  }

  // MARK: - Embedded HLS tracks

  static func isEnglish(_ lang: String) -> Bool {
    SubtitleTracks.matches(language: "en", lang)
  }

  static func looksLikeCCDisplayName(_ name: String) -> Bool {
    SubtitleTracks.looksLikeCCDisplayName(name)
  }

  static func isForcedDisplayName(_ name: String) -> Bool {
    SubtitleTracks.isForcedDisplayName(name)
  }
}
