//
//  SubtitleTrackMemory.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

/// The shape `subtitleTrackChoices` was stored in before `TrackPreferenceLedger`.
///
/// Kept only so `TrackPreferenceStore` can read that key once and migrate it — the
/// language code in a `SubtitleTrackReference` converts cleanly, unlike the audio side,
/// which stored a rendition display name. Delete this once a release has shipped with the
/// migration in it.
struct SubtitleChoice: Codable, Equatable {
  var primary: SubtitleTrackReference?
  var secondary: SubtitleTrackReference?

  /// A title watched with subtitles off is worth remembering too — otherwise the
  /// default preference turns them back on every episode.
  var isEmpty: Bool { primary == nil && secondary == nil }
}
