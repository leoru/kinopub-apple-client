//
//  SubtitleSelector.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

/// Building and naming subtitle tracks. **Which of them a title opens with is
/// `TrackResolver`** — this type no longer decides, it only catalogues.
enum SubtitleSelector {

  struct Selection: Equatable {
    var primary: SubtitleTrack?
    var secondary: SubtitleTrack?

    var isOff: Bool { primary == nil && secondary == nil }
  }

  static func tracks(in subtitles: [Subtitle]) -> [SubtitleTrack] {
    SubtitleTracks.catalog(subtitles)
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
