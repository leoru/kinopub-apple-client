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

  /// Audio tracks as "Русский — Дубляж (Flarrow Films)".
  var audioTrackDescriptions: [String] {
    if let audios = videos?.first?.audios, !audios.isEmpty {
      return audios.map { Self.describe(lang: $0.lang, type: $0.type?.title, author: $0.author?.title) }
    }
    let episodeAudios = seasons?.first?.episodes.first?.audios ?? []
    return episodeAudios.map { Self.describe(lang: $0.lang, type: $0.type?.title, author: $0.author?.title) }
  }

  private static func describe(lang: String, type: String?, author: String?) -> String {
    var parts = [LanguageNames.name(for: lang)]
    if let type, !type.isEmpty {
      parts.append(type)
    }
    var line = parts.joined(separator: " — ")
    if let author, !author.isEmpty {
      line += " (\(author))"
    }
    return line
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
/// Foundation knows the ISO 639-2 codes the API uses (`rus`, `cze`, `baq`…), so it
/// does the work and localizes into the current language; the small table below only
/// covers codes it declines, and the raw code is the last resort.
public enum LanguageNames {
  private static let fallbacks: [String: String] = [
    "rus": "Русский", "ru": "Русский",
    "ukr": "Українська", "uk": "Українська",
    "eng": "English", "en": "English"
  ]

  public static func name(for code: String) -> String {
    let key = code.lowercased().trimmingCharacters(in: .whitespaces)
    guard !key.isEmpty else { return "" }

    if let localized = Locale.current.localizedString(forLanguageCode: key),
       localized.lowercased() != key {
      return localized.prefix(1).uppercased() + localized.dropFirst()
    }
    return fallbacks[key] ?? code
  }
}
