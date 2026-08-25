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
  /// Signage and alien dialogue only.
  var isForcedRendition: Bool { get }
  /// Captioning rather than dialogue — SDH, transcribed sound.
  var isCaptioningRendition: Bool { get }
}

/// Bridging between what `TrackResolver` decides — a `SubtitleTrack` from the API's list —
/// and the renditions the system player can actually select, off tvOS.
///
/// **Identity is the language and the kind of track; position only separates what those
/// two cannot.** There is no id in common between the API's list and the master, and
/// unlike a dub a subtitle carries no label to match on: `Subtitle` is `lang`, `shift`,
/// `embed` and a URL, with no title and no studio, so there is no equivalent of
/// `AudioRenditions`' name match. What the language *can* carry, it does — three-letter
/// kino.pub codes resolve through the same table as everything else (`LanguageNames`), so
/// `ukr` finds `uk` and `phi` finds `fil`, and `ai`, their machine-translated Russian,
/// stays its own language instead of colliding with the human Russian track beside it.
///
/// Position is counted inside one language *and* one kind, from the lists as they are at
/// this moment — never a number remembered from an earlier episode. A track added to the
/// item later shifts both lists together, which is the point: the pairing is between two
/// descriptions of the same file fetched in the same breath, not across time.
public enum SubtitleRenditions {

  /// The rendition carrying `track`, or `nil` when this master offers nothing of its
  /// language — in which case the honest answer is no subtitles rather than a wrong line.
  public static func rendition<R: SubtitleRendition>(for track: SubtitleTrack,
                                                     among tracks: [SubtitleTrack],
                                                     in renditions: [R]) -> R? {
    renditionIndex(for: track, among: tracks, in: renditions).map { renditions[$0] }
  }

  /// The same answer as a position in the group.
  ///
  /// By index, because two renditions of one language and kind are alike in everything
  /// this protocol can see: *which* of them is meant is the entire question, and a value
  /// cannot carry it. The caller has the group, so it can hold an index.
  public static func renditionIndex<R: SubtitleRendition>(for track: SubtitleTrack,
                                                          among tracks: [SubtitleTrack],
                                                          in renditions: [R]) -> Int? {
    let sameLanguage = renditions.indices.filter { matches(track.lang, renditions[$0]) }
    guard !sameLanguage.isEmpty else { return nil }

    let sameKind = sameLanguage.filter { isSameKind(renditions[$0], as: track) }
    guard !sameKind.isEmpty else {
      // Nothing of that exact kind. A plain rendition stands in for it better than signage
      // does — forced subtitles leave most of a film silent.
      return sameLanguage.first { !renditions[$0].isForcedRendition } ?? sameLanguage.first
    }

    let siblings = tracks.filter {
      matches($0.lang, renditions[sameKind[0]]) && isSameKind(renditions[sameKind[0]], as: $0)
    }
    guard let position = siblings.firstIndex(of: track), sameKind.indices.contains(position) else {
      return sameKind.first
    }
    return sameKind[position]
  }

  /// The track the rendition at `index` stands for — the same pairing read backwards, so a
  /// choice made in the system player's own menu can be written down in our terms and
  /// taught to the next episode.
  public static func track<R: SubtitleRendition>(forRenditionAt index: Int,
                                                 among renditions: [R],
                                                 in tracks: [SubtitleTrack]) -> SubtitleTrack? {
    guard renditions.indices.contains(index) else { return nil }
    let rendition = renditions[index]
    let sameLanguage = tracks.filter { matches($0.lang, rendition) }
    guard !sameLanguage.isEmpty else { return nil }

    let sameKind = sameLanguage.filter { isSameKind(rendition, as: $0) }
    guard !sameKind.isEmpty else { return sameLanguage.first { !$0.isForced } ?? sameLanguage.first }

    let position = renditions[..<index].filter {
      matches(sameKind[0].lang, $0) && isSameKind($0, as: sameKind[0])
    }.count
    guard sameKind.indices.contains(position) else { return sameKind.first }
    return sameKind[position]
  }

  private static func matches(_ language: String, _ rendition: some SubtitleRendition) -> Bool {
    SubtitleTracks.languageKey(language)
      == SubtitleTracks.languageKey(rendition.renditionLanguageCode)
  }

  private static func isSameKind(_ rendition: some SubtitleRendition, as track: SubtitleTrack) -> Bool {
    rendition.isForcedRendition == track.isForced && rendition.isCaptioningRendition == track.isCC
  }
}
