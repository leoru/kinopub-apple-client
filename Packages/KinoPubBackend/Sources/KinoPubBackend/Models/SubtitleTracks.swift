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

  /// ISO 639-2 → 639-1 for the codes the API actually sends; Foundation covers the
  /// rest, and an unknown code is left alone so it can still match itself.
  private static let twoLetterCodes: [String: String] = [
    "eng": "en", "rus": "ru", "ukr": "uk", "ger": "de", "deu": "de", "fre": "fr",
    "fra": "fr", "spa": "es", "ita": "it", "jpn": "ja", "kor": "ko", "chi": "zh",
    "zho": "zh", "pol": "pl", "tur": "tr", "ara": "ar", "por": "pt", "cze": "cs",
    "ces": "cs", "swe": "sv", "nor": "no", "fin": "fi", "dan": "da", "dut": "nl",
    "nld": "nl", "heb": "he", "hin": "hi", "gre": "el", "ell": "el", "bul": "bg",
    "ron": "ro", "rum": "ro", "hun": "hu", "srp": "sr", "hrv": "hr", "slo": "sk",
    "slk": "sk", "lit": "lt", "lav": "lv", "est": "et", "kaz": "kk", "bel": "be"
  ]

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
  public static func languageKey(_ code: String) -> String {
    let trimmed = code.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let base = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
    if let mapped = twoLetterCodes[base] { return mapped }
    return base
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
