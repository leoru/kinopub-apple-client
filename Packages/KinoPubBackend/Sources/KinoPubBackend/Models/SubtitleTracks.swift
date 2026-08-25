//
//  SubtitleTracks.swift
//
//

import Foundation

/// One subtitle track of an item, with everything the player and the picker need to
/// tell it apart from its neighbours.
public struct SubtitleTrack: Identifiable, Hashable {
  public let index: Int
  public let subtitle: Subtitle
  public let isCC: Bool
  public let isForced: Bool
  /// Position among the tracks of the same language — what makes a remembered choice
  /// findable again on the next episode, whose sidecar URLs are all different.
  public let ordinal: Int

  public var id: Int { index }
  public var lang: String { subtitle.lang }
  public var url: String { subtitle.url }
  public var hasSidecar: Bool {
    !subtitle.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  public var displayName: String {
    var name = LanguageNames.name(for: subtitle.lang)
    if name.isEmpty { name = subtitle.lang }
    var badges: [String] = []
    if isForced { badges.append("Forced") }
    if isCC { badges.append("CC") }
    if ordinal > 0 { badges.append("\(ordinal + 1)") }
    guard !badges.isEmpty else { return name }
    return "\(name) (\(badges.joined(separator: " · ")))"
  }

  public var reference: SubtitleTrackReference {
    SubtitleTrackReference(lang: subtitle.lang, isCC: isCC, ordinal: ordinal)
  }
}

/// A remembered choice, stored rather than the track itself.
///
/// Sidecar URLs change from episode to episode, so remembering one would pre-select
/// nothing on the next episode. Language + CC-ness + position within that language
/// survives the jump.
public struct SubtitleTrackReference: Codable, Hashable {
  public let lang: String
  public let isCC: Bool
  public let ordinal: Int

  public init(lang: String, isCC: Bool, ordinal: Int) {
    self.lang = lang
    self.isCC = isCC
    self.ordinal = ordinal
  }
}

public enum SubtitleTracks {

  /// Markers that mean "this track is captioning, not dialogue".
  private static let ccMarkers: Set<String> = ["cc", "sdh", "hi", "caption", "captions"]
  private static let forcedMarkers: Set<String> = ["forced", "force"]

  // MARK: - Building

  public static func catalog(_ subtitles: [Subtitle]) -> [SubtitleTrack] {
    var seenPerLanguage: [String: Int] = [:]
    return subtitles.enumerated().map { index, subtitle in
      let key = languageKey(subtitle.lang)
      let ordinal = seenPerLanguage[key, default: 0]
      seenPerLanguage[key] = ordinal + 1
      return SubtitleTrack(index: index,
                           subtitle: subtitle,
                           isCC: looksLikeCC(subtitle),
                           isForced: isForced(subtitle),
                           ordinal: ordinal)
    }
  }

  // MARK: - Sorting / grouping

  /// Preferred languages first (system order), then the rest A–Z; within a language
  /// regular before CC before Forced, then ordinal.
  public static func sort(_ tracks: [SubtitleTrack],
                          preferredLanguages: [String] = Locale.preferredLanguages) -> [SubtitleTrack] {
    tracks.sorted {
      sortKey(for: $0, preferredLanguages: preferredLanguages)
        < sortKey(for: $1, preferredLanguages: preferredLanguages)
    }
  }

  public static func languageGroups(for tracks: [SubtitleTrack],
                                    preferredLanguages: [String] = Locale.preferredLanguages)
  -> [MediaLanguageGroup] {
    let sorted = sort(tracks, preferredLanguages: preferredLanguages)
    var order: [String] = []
    var byLanguage: [String: [SubtitleTrack]] = [:]
    for track in sorted {
      let key = languageKey(track.lang)
      if byLanguage[key] == nil { order.append(key) }
      byLanguage[key, default: []].append(track)
    }
    return order.compactMap { key in
      guard let group = byLanguage[key], let first = group.first else { return nil }
      return MediaLanguageGroup(key: key,
                                name: LanguageNames.name(for: first.lang),
                                detailLines: summaryLines(for: group))
    }
  }

  private static func sortKey(for track: SubtitleTrack,
                              preferredLanguages: [String]) -> SortKey {
    let key = languageKey(track.lang)
    let priority: Int
    if let idx = preferredLanguages.firstIndex(where: { languageKey($0) == key }) {
      priority = idx
    } else {
      priority = preferredLanguages.count
    }
    let alpha = LanguageNames.name(for: track.lang).lowercased()
    return SortKey(languagePriority: priority,
                   languageName: alpha.isEmpty ? key : alpha,
                   isForced: track.isForced,
                   isCC: track.isCC,
                   ordinal: track.ordinal)
  }

  private struct SortKey: Comparable {
    let languagePriority: Int
    let languageName: String
    let isForced: Bool
    let isCC: Bool
    let ordinal: Int

    static func < (l: SortKey, r: SortKey) -> Bool {
      if l.languagePriority != r.languagePriority { return l.languagePriority < r.languagePriority }
      if l.languageName != r.languageName { return l.languageName < r.languageName }
      if l.isForced != r.isForced { return !l.isForced && r.isForced }
      if l.isCC != r.isCC { return !l.isCC && r.isCC }
      return l.ordinal < r.ordinal
    }
  }

  /// Badges under the language name — omitted when a language has a single plain track.
  private static func summaryLines(for tracks: [SubtitleTrack]) -> [String] {
    guard tracks.count > 1 || tracks.contains(where: { $0.isCC || $0.isForced }) else {
      return []
    }
    var parts: [String] = []
    if tracks.count > 1 {
      parts.append("\(tracks.count)")
    }
    if tracks.contains(where: \.isCC) {
      parts.append(String(localized: "CC", bundle: .module))
    }
    if tracks.contains(where: \.isForced) {
      parts.append(String(localized: "Forced", bundle: .module))
    }
    guard !parts.isEmpty else { return [] }
    return [parts.joined(separator: " ∙ ")]
  }

  // MARK: - Resolving

  /// The track a remembered choice points at, on an item that may not be the one the
  /// choice was made on. Language first, then CC-ness, then position.
  public static func resolve(_ reference: SubtitleTrackReference,
                             in tracks: [SubtitleTrack]) -> SubtitleTrack? {
    let key = languageKey(reference.lang)
    let sameLanguage = tracks.filter { languageKey($0.lang) == key }
    guard !sameLanguage.isEmpty else { return nil }

    let sameKind = sameLanguage.filter { $0.isCC == reference.isCC }
    let candidates = sameKind.isEmpty ? sameLanguage : sameKind

    if let exact = candidates.first(where: { $0.ordinal == reference.ordinal }) {
      return exact
    }
    return candidates.first
  }

  /// The best track in a language when nothing was remembered.
  ///
  /// Forced tracks are never a default: they carry signage and alien dialogue only, so
  /// they leave most of a film silent.
  public static func preferred(language code: String,
                               in tracks: [SubtitleTrack],
                               preferNonCC: Bool) -> SubtitleTrack? {
    let key = languageKey(code)
    let matching = tracks.filter { languageKey($0.lang) == key && !$0.isForced }
    guard !matching.isEmpty else { return nil }

    var ranked = matching
    if preferNonCC {
      let nonCC = matching.filter { !$0.isCC }
      ranked = nonCC.isEmpty ? matching : nonCC
    }

    // A fetchable sidecar is what the cue overlay and the word panel read.
    return ranked.first(where: \.hasSidecar) ?? ranked.first
  }

  // MARK: - Heuristics

  public static func matches(language code: String, _ lang: String) -> Bool {
    languageKey(code) == languageKey(lang)
  }

  /// Canonical form of a language code: `eng`, `en-US` and `EN` all land on `en`.
  ///
  /// One table for the whole app, in `LanguageNames` — this used to keep a second, shorter
  /// copy of it, which is how `uzb` and `phi` ended up matching nothing while the display
  /// name beside them was perfectly correct.
  public static func languageKey(_ code: String) -> String {
    LanguageNames.canonicalCode(code)
  }

  public static func looksLikeCC(_ subtitle: Subtitle) -> Bool {
    !tokens(in: subtitle).isDisjoint(with: ccMarkers)
  }

  public static func isForced(_ subtitle: Subtitle) -> Bool {
    !tokens(in: subtitle).isDisjoint(with: forcedMarkers)
  }

  public static func looksLikeCCDisplayName(_ name: String) -> Bool {
    !tokens(in: name).isDisjoint(with: ccMarkers)
  }

  public static func isForcedDisplayName(_ name: String) -> Bool {
    !tokens(in: name).isDisjoint(with: forcedMarkers)
  }

  /// Whole words only. Matching substrings used to call `hindi.srt` a CC track and
  /// `enforced.srt` a forced one.
  ///
  /// `hi` is dropped from the language side on purpose: as a marker it means
  /// hearing-impaired, as a language code it means Hindi.
  private static func tokens(in subtitle: Subtitle) -> Set<String> {
    tokens(in: subtitle.url).union(tokens(in: subtitle.lang).subtracting(["hi"]))
  }

  private static func tokens(in text: String) -> Set<String> {
    Set(text.lowercased()
      .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
      .map(String.init))
  }
}
