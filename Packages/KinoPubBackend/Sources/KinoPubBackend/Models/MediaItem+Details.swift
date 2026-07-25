//
//  MediaItem+Details.swift
//
//

import Foundation

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

  /// Runtime to display: the per-episode average for a series, whose `total` is the
  /// sum of every episode and reads as nonsense on its own.
  var displayDuration: String {
    let seconds = isSeries ? duration.average : duration.total
    return Duration.hoursMinutes(seconds: Int(seconds))
  }

  /// Everything end to end — only meaningful for a series, where it is shown as its
  /// own row alongside the per-episode runtime.
  var totalDurationDisplay: String? {
    guard isSeries, duration.total > 0 else { return nil }
    return Duration.hoursMinutes(seconds: Int(duration.total))
  }

  /// Subtitle languages offered, de-duplicated and human readable.
  ///
  /// A film carries its tracks on `videos`; a series carries them per episode, so
  /// fall back to the first episode rather than showing nothing for every series.
  var subtitleLanguages: [String] {
    let fromVideos = videos?.first?.subtitles ?? []
    let langs = fromVideos.isEmpty
      ? (seasons?.first?.episodes.first?.subtitles ?? []).map(\.lang)
      : fromVideos.map(\.lang)
    return Self.uniqueLanguageNames(langs)
  }

  /// Audio tracks as "Russian ∙ multi-voice ∙ Flarrow Films", ordered like the
  /// system audio picker: preferred languages, then A–Z, kind, studio.
  var audioTrackDescriptions: [String] {
    if let audios = videos?.first?.audios, !audios.isEmpty {
      return AudioTracks.descriptions(for: AudioTracks.catalog(audios))
    }
    let episodeAudios = seasons?.first?.episodes.first?.audios ?? []
    return AudioTracks.descriptions(for: AudioTracks.catalog(episodeAudios))
  }

  private static func splitNames(_ raw: String) -> [String] {
    raw.split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func uniqueLanguageNames(_ codes: [String]) -> [String] {
    var seen = Set<String>()
    return codes.compactMap { code in
      let name = LanguageNames.name(for: code)
      guard !name.isEmpty, seen.insert(name).inserted else { return nil }
      return name
    }
  }
}

/// Maps the API's language codes to display names in the reader's language.
///
/// Foundation localizes ISO codes (`rus`, `ukr`, `jpn`…) via `Locale`. A small
/// 639-2 → 639-1 alias table covers codes some OS builds only resolve as ISO-1.
public enum LanguageNames {
  /// Common bibliographic / kino.pub codes → ISO 639-1 when Locale needs the short form.
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
    "hau": "ha", "yor": "yo", "ibo": "ig", "ful": "ff"
  ]

  public static func name(for code: String) -> String {
    let key = code.lowercased().trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else { return "" }

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
