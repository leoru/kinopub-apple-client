//
//  AudioRenditions.swift
//
//

import Foundation

/// One audio rendition as the player sees it, reduced to what matching needs.
///
/// A protocol rather than `AVMediaSelectionOption` on purpose: the matching rules below
/// are the part with the sharp edges — duplicate names, suffixes, missing metadata — and
/// they are worth testing without an asset, a network and a simulator. `AVFoundation`
/// conforms to this in the app.
public protocol AudioRendition {
  /// The rendition's `NAME=` from the master playlist, not the language `displayName`.
  var renditionName: String { get }
  var renditionLanguageCode: String { get }
  var describesVideoForAccessibility: Bool { get }
}

/// Bridging between what `TrackResolver` decides — an `AudioTrackInfo` from the API — and
/// what the player can actually select.
public enum AudioRenditions {

  /// HLS forbids two identical `NAME=` in one group, so the master rewrite
  /// (`AudioTracks.uniquedHLSLabels`) uniques duplicates with this. Matching has to
  /// see past it.
  static let duplicateSuffix = " ∙ "

  /// The menu to reason about when the API gave no track metadata — a downloaded file, or
  /// a master we did not relabel. Reading kind and studio back out of the rendition's own
  /// name is worse than the API's fields, and much better than AVFoundation's default of
  /// "first rendition in the system language".
  ///
  /// `index` is the rendition's position, which is what `rendition(for:…)` matches on.
  public static func menu(from renditions: [any AudioRendition]) -> [AudioTrackInfo] {
    renditions.enumerated().map { index, rendition in
      let name = rendition.renditionName
      return AudioTrackInfo(lang: rendition.renditionLanguageCode,
                            typeTitle: name,
                            authorTitle: AudioTracks.authorFromDisplayName(name),
                            channels: AudioTracks.channelCount(fromLabel: name),
                            index: index,
                            isAudioDescription: rendition.describesVideoForAccessibility)
    }
  }

  /// The rendition carrying `track`.
  ///
  /// `apiTracks` empty means the menu was synthesised from these renditions, so the
  /// track's `index` is the answer. Otherwise the rendition was named after the API row
  /// and matches by label, exactly first and then past a duplicate suffix.
  public static func rendition<R: AudioRendition>(for track: AudioTrackInfo,
                                                  in renditions: [R],
                                                  apiTracks: [AudioTrackInfo]) -> R? {
    guard !apiTracks.isEmpty else {
      return renditions.indices.contains(track.index) ? renditions[track.index] : nil
    }
    let label = AudioTracks.baseLabel(track)
    if let exact = renditions.first(where: { $0.renditionName == label }) { return exact }
    return renditions.first { rendition in
      let name = rendition.renditionName
      guard name.hasPrefix(label) else { return false }
      return name.dropFirst(label.count).hasPrefix(duplicateSuffix)
    }
  }

  /// How the dub playing right now is written down: the API row when the rendition maps
  /// back to one, otherwise read off the rendition's own name.
  public static func signature(for rendition: any AudioRendition,
                               apiTracks: [AudioTrackInfo]) -> AudioTrackSignature {
    let name = rendition.renditionName
    if let track = apiTracks.first(where: { AudioTracks.baseLabel($0) == name })
      ?? apiTracks.first(where: { name.hasPrefix(AudioTracks.baseLabel($0) + duplicateSuffix) }) {
      return track.signature
    }
    return AudioTrackSignature(languageKey: rendition.renditionLanguageCode,
                               kindRank: AudioTracks.kindRank(fromLabel: name),
                               studio: AudioTracks.authorFromDisplayName(name))
  }
}
