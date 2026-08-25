//
//  MediaItem+Details.swift
//
//

import Foundation

public extension Season {
  /// The real season number parsed from the title ("Сезон 14" / "Season 14" / "14
  /// сезон"), for when kino.pub re-numbers its blocks from 1. Nil when the title
  /// carries no digits (specials and oddly-named blocks).
  var titleSeasonNumber: Int? {
    guard let range = title.range(of: #"\d+"#, options: .regularExpression) else { return nil }
    return Int(title[range])
  }
}

public extension MediaItem {

  /// kino.pub's own vote is a thumbs up/down tally, not a score, so it is reported
  /// as one.
  ///
  /// `rating` is the net count (likes minus dislikes, negative when disliked) and
  /// `rating_votes` the total, which recovers both exactly:
  /// likes = (total + net) / 2, dislikes = (total − net) / 2.
  /// Checked against the API: 36 net over 328 votes → 182/146, matching its 55%.
  var communityVotes: (likes: Int, dislikes: Int)? {
    guard ratingVotes > 0 else { return nil }
    let likes = (ratingVotes + rating) / 2
    let dislikes = ratingVotes - likes
    guard likes >= 0, dislikes >= 0 else { return nil }
    return (likes, dislikes)
  }

  /// Every production country. The API returns them all; only showing the first
  /// throws data away.
  var countryNames: [String] {
    countries.map(\.title).filter { !$0.isEmpty }
  }

  var genreNames: [String] {
    genres.compactMap(\.title).filter { !$0.isEmpty }
  }

  var castMembers: [String] {
    Self.splitNames(cast)
  }

  var directorNames: [String] {
    Self.splitNames(director)
  }

  /// Runtime to display: per-episode average for a series; film total with minutes
  /// in parentheses when ≥ 1 hour (`1h 45m (105 min)`).
  var displayDuration: String {
    let seconds = isSeries ? Int(duration.average) : Int(duration.total)
    return isSeries
      ? Duration.compact(seconds: seconds)
      : Duration.compactWithMinutes(seconds: seconds)
  }

  /// End-to-end runtime for a series (`1d 12h 4m (5203 min)` when long enough).
  var totalDurationDisplay: String? {
    guard isSeries, duration.total > 0 else { return nil }
    return Duration.compactWithMinutes(seconds: Int(duration.total))
  }

  /// Compact + minutes for the Kinopoisk-style continuous-watch line under a long total.
  var continuousWatchNoteParts: (compact: String, totalMinutes: Int)? {
    guard isSeries, duration.total >= 24 * 60 * 60 else { return nil }
    let seconds = Int(duration.total)
    let minutes = Int((Double(seconds) / 60).rounded())
    return (Duration.compact(seconds: seconds), minutes)
  }

  /// Localization key for the content type (`MediaType_Movie`, …), or the raw API value.
  var contentTypeTitleKey: String {
    if let known = MediaType(rawValue: type) {
      return known.singularTitleKey
    }
    return type
  }

  var contentTypeFilter: MediaType? {
    MediaType(rawValue: type)
  }

  /// Subtype localization key when the API sends one (`multi` for multi-part films).
  var contentSubtypeTitleKey: String? {
    let trimmed = subtype.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }
    switch trimmed.lowercased() {
    case "multi": return "MediaItem_SubtypeMulti"
    default: return nil
    }
  }

  /// Raw subtype when it is not a known key — still surface it rather than drop it.
  var contentSubtypeRaw: String? {
    let trimmed = subtype.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.lowercased() != "null" else { return nil }
    if contentSubtypeTitleKey != nil { return nil }
    return trimmed
  }

  /// Original / also-known-as title when it differs from the localized one.
  var alsoKnownAsTitle: String? {
    let original = originalTitle
    let localized = localizedTitle
    guard !original.isEmpty, original != localized else { return nil }
    return original
  }

  /// Season and episode counts for the Volume row.
  var volumeCounts: (seasons: Int, episodes: Int)? {
    guard let seasons, !seasons.isEmpty else { return nil }
    let episodes = seasons.reduce(0) { $0 + $1.episodes.count }
    return (seasons.count, episodes)
  }

  /// Series completion from kino.pub `finished`.
  var seriesStatusKey: String? {
    guard isSeries else { return nil }
    return finished ? "MediaItem_StatusEnded" : "MediaItem_StatusOngoing"
  }

  /// Top advertised quality from the item, else distinct file qualities.
  var qualityDisplay: String? {
    if quality > 0 { return "\(quality)p" }
    var seen = Set<String>()
    var unique: [String] = []
    for q in detailFiles.map(\.quality) where !q.isEmpty && seen.insert(q).inserted {
      unique.append(q)
    }
    guard !unique.isEmpty else { return nil }
    return unique.joined(separator: ", ")
  }

  /// One line per distinct video file: `1080p · h264 · 1920×1080`.
  var videoTechLines: [String] {
    var seen = Set<String>()
    var lines: [String] = []
    for file in detailFiles {
      let key = "\(file.qualityID)-\(file.codec)-\(file.w)x\(file.h)"
      guard seen.insert(key).inserted else { continue }
      var parts: [String] = []
      if !file.quality.isEmpty { parts.append(file.quality) }
      if !file.codec.isEmpty { parts.append(file.codec) }
      if file.w > 0, file.h > 0 { parts.append("\(file.w)×\(file.h)") }
      guard !parts.isEmpty else { continue }
      lines.append(parts.joined(separator: " · "))
    }
    return lines
  }

  var detailFiles: [FileInfo] {
    if let files = videos?.first?.files, !files.isEmpty { return files }
    return seasons?.first?.episodes.first?.files ?? []
  }

  /// True when Uploaded and Last Update fall on the same calendar day.
  var uploadedSameDayAsUpdated: Bool {
    guard createdAt > 0, updatedAt > 0 else { return true }
    let created = Date(timeIntervalSince1970: TimeInterval(createdAt))
    let updated = Date(timeIntervalSince1970: TimeInterval(updatedAt))
    return Calendar.current.isDate(created, inSameDayAs: updated)
  }

  /// Subtitle languages offered, de-duplicated and human readable.
  ///
  /// A film carries its tracks on `videos`; a series carries them per episode, so
  /// fall back to the first episode rather than showing nothing for every series.
  var subtitleLanguages: [String] {
    subtitleLanguageGroups.map(\.name)
  }

  /// Subtitle tracks for the detail page — film `videos`, else the first episode.
  var detailSubtitleTracks: [SubtitleTrack] {
    let fromVideos = videos?.first?.subtitles ?? []
    let subs = fromVideos.isEmpty
      ? (seasons?.first?.episodes.first?.subtitles ?? [])
      : fromVideos
    return SubtitleTracks.catalog(subs)
  }

  /// Subtitles grouped by language for the Languages column.
  func subtitleLanguageGroups(preferredLanguages: [String] = Locale.preferredLanguages)
  -> [MediaLanguageGroup] {
    SubtitleTracks.languageGroups(for: detailSubtitleTracks,
                                  preferredLanguages: preferredLanguages)
  }

  /// Convenience for callers that want the system preferred order.
  var subtitleLanguageGroups: [MediaLanguageGroup] {
    subtitleLanguageGroups()
  }

  /// Audio tracks as "Russian ∙ Multi-voice, Flarrow Films", ordered like the
  /// system audio picker: preferred languages, then A–Z, kind, studio.
  var audioTrackDescriptions: [String] {
    AudioTracks.descriptions(for: detailAudioTracks)
  }

  /// Audio tracks for the detail page — film `videos`, else the first episode.
  var detailAudioTracks: [AudioTrackInfo] {
    if let audios = videos?.first?.audios, !audios.isEmpty {
      return AudioTracks.catalog(audios)
    }
    let episodeAudios = seasons?.first?.episodes.first?.audios ?? []
    return AudioTracks.catalog(episodeAudios)
  }

  /// Audio grouped by language for the Languages column.
  func audioLanguageGroups(preferredLanguages: [String] = Locale.preferredLanguages)
  -> [MediaLanguageGroup] {
    AudioTracks.languageGroups(for: detailAudioTracks,
                               preferredLanguages: preferredLanguages)
  }

  var audioLanguageGroups: [MediaLanguageGroup] {
    audioLanguageGroups()
  }

  private static func splitNames(_ raw: String) -> [String] {
    raw.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

/// Maps the API's language codes to display names in the reader's language.
///
/// Foundation localizes ISO codes (`rus`, `ukr`, `jpn`…) via `Locale`. A small
/// 639-2 → 639-1 alias table covers codes some OS builds only resolve as ISO-1.
public enum LanguageNames {
  /// Common bibliographic / kino.pub codes → ISO 639-1 when Locale needs the short form.
  ///
  /// **The one table.** `SubtitleTracks.languageKey` — and through it every audio and
  /// subtitle match in the app — resolves codes here rather than keeping a second, shorter
  /// copy of the same idea; the copy that used to live there was missing `uzb` and `phi`,
  /// both of which kino.pub ships.
  private static let aliases: [String: String] = [
    "rus": "ru", "ukr": "uk", "eng": "en", "jpn": "ja", "deu": "de", "ger": "de",
    "fra": "fr", "fre": "fr", "spa": "es", "ita": "it", "zho": "zh", "chi": "zh",
    "pol": "pl", "tur": "tr", "kaz": "kk", "bel": "be", "por": "pt", "hin": "hi",
    "kor": "ko", "ara": "ar", "heb": "he", "tha": "th", "vie": "vi", "ell": "el",
    "gre": "el", "hun": "hu", "ces": "cs", "cze": "cs", "swe": "sv", "nld": "nl",
    "dut": "nl", "fin": "fi", "ron": "ro", "rum": "ro", "bul": "bg", "hrv": "hr",
    "srp": "sr", "slk": "sk", "slo": "sk", "lit": "lt", "lav": "lv", "est": "et",
    "kat": "ka", "geo": "ka", "hye": "hy", "arm": "hy", "aze": "az", "uzb": "uz",
    "fas": "fa", "per": "fa", "ind": "id", "msa": "ms", "may": "ms", "fil": "fil",
    "tgl": "tl", "nor": "no", "dan": "da", "isl": "is", "ice": "is", "gle": "ga",
    "cym": "cy", "wel": "cy", "cat": "ca", "eus": "eu", "baq": "eu", "glg": "gl",
    "sqi": "sq", "alb": "sq", "mkd": "mk", "mac": "mk", "slv": "sl", "bos": "bs",
    "mlt": "mt", "epo": "eo", "lat": "la", "mon": "mn", "nep": "ne", "urd": "ur",
    "ben": "bn", "tam": "ta", "tel": "te", "kan": "kn", "mal": "ml", "pan": "pa",
    "guj": "gu", "mar": "mr", "sin": "si", "mya": "my", "bur": "my", "khm": "km",
    "lao": "lo", "amh": "am", "swa": "sw", "afr": "af", "glv": "gv", "fao": "fo",
    "ltz": "lb", "roh": "rm", "yid": "yi", "jav": "jv", "sun": "su", "ceb": "ceb",
    "haw": "haw", "smo": "sm", "ton": "to", "mlg": "mg", "xho": "xh", "zul": "zu",
    "sna": "sn", "sot": "st", "tsn": "tn", "tso": "ts", "ven": "ve", "nbl": "nr",
    "ssw": "ss", "kin": "rw", "run": "rn", "orm": "om", "som": "so", "tir": "ti",
    "hau": "ha", "yor": "yo", "ibo": "ig", "ful": "ff",
    // kino.pub's own id for Filipino: `phi` is the collective code for the Philippine
    // languages, not a language, and the master tags these `fil`.
    "phi": "fil"
  ]

  /// kino.pub's machine-translated Russian, which their reference list calls `РусскийAI`.
  /// **Not a language and deliberately not an alias of `ru`:** an item can carry both, and
  /// collapsing them would let a match land on the wrong one — the whole reason a track is
  /// identified by language in the first place.
  public static let machineTranslatedRussian = "ai"

  /// The canonical form of a language code — `eng`, `en-US` and `EN` all land on `en`.
  /// Unknown codes are returned as they came so they can still match themselves.
  public static func canonicalCode(_ code: String) -> String {
    let trimmed = code.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let base = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
    return aliases[base] ?? base
  }

  public static func name(for code: String) -> String {
    let key = code.lowercased().trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else { return "" }
    if key == machineTranslatedRussian {
      return String(localized: "Russian (AI)", bundle: .module)
    }

    let lookup = aliases[key] ?? key
    if let localized = Locale.current.localizedString(forLanguageCode: lookup)
        ?? Locale.current.localizedString(forLanguageCode: key),
       localized.lowercased() != lookup,
       localized.lowercased() != key {
      return sentenceCased(localized)
    }
    return code
  }

  /// Locale often returns lowercase adjectives ("русский", "rusų"); title-case the
  /// first character so the language leads the audio line.
  private static func sentenceCased(_ name: String) -> String {
    guard let first = name.first else { return name }
    return String(first).uppercased() + name.dropFirst()
  }
}
