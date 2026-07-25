//
//  AudioTracks.swift
//
//

import Foundation

/// One audio rendition of an item, with everything the detail page and the player
/// default-picker need to order and label it.
public struct AudioTrackInfo: Hashable {
  public let lang: String
  public let typeId: Int?
  public let typeTitle: String?
  public let typeShortTitle: String?
  public let authorTitle: String?
  public let channels: Int
  public let codec: String
  public let index: Int
  public let isAudioDescription: Bool

  public init(lang: String,
              typeId: Int? = nil,
              typeTitle: String? = nil,
              typeShortTitle: String? = nil,
              authorTitle: String? = nil,
              channels: Int = 2,
              codec: String = "",
              index: Int = 0,
              isAudioDescription: Bool = false) {
    self.lang = lang
    self.typeId = typeId
    self.typeTitle = typeTitle
    self.typeShortTitle = typeShortTitle
    self.authorTitle = authorTitle
    self.channels = channels
    self.codec = codec
    self.index = index
    self.isAudioDescription = isAudioDescription
  }

  public init(_ audio: VideoAudio) {
    self.init(lang: audio.lang,
              typeId: audio.type?.id,
              typeTitle: audio.type?.title,
              typeShortTitle: audio.type?.shortTitle,
              authorTitle: audio.author?.title,
              channels: audio.channels,
              codec: audio.codec,
              index: audio.index,
              isAudioDescription: AudioTracks.looksLikeAudioDescription(audio.type?.title))
  }

  public init(_ audio: EpisodeAudio) {
    self.init(lang: audio.lang,
              typeId: audio.type?.id,
              typeTitle: audio.type?.title,
              typeShortTitle: audio.type?.shortTitle,
              authorTitle: audio.author?.title,
              channels: audio.channels,
              codec: audio.codec,
              index: audio.index,
              isAudioDescription: AudioTracks.looksLikeAudioDescription(audio.type?.title))
  }
}

/// Shared sort ladder for the detail-page Audio column and the player's default pick.
///
/// Preferred languages first (system order), then the rest A–Z; within a language
/// regular before AD; then kind (DUB → MVO → DVO → VO → AVO → Orig); then studio
/// A–Z (anonymous last); more channels before fewer; stable `index` last.
public enum AudioTracks {

  /// API type ids: 1 DUB, 2 MVO, 3 DVO, 4 VO, 5 AVO, 6 Orig. Lower rank sorts first.
  public static let kindRankUnknown = 6

  // MARK: - Catalog

  public static func catalog(_ audios: [VideoAudio]) -> [AudioTrackInfo] {
    audios.map(AudioTrackInfo.init)
  }

  public static func catalog(_ audios: [EpisodeAudio]) -> [AudioTrackInfo] {
    audios.map(AudioTrackInfo.init)
  }

  // MARK: - Sorting

  public static func sort(_ tracks: [AudioTrackInfo],
                          preferredLanguages: [String] = Locale.preferredLanguages) -> [AudioTrackInfo] {
    tracks.sorted {
      sortKey(for: $0, preferredLanguages: preferredLanguages)
        < sortKey(for: $1, preferredLanguages: preferredLanguages)
    }
  }

  public static func sortKey(for track: AudioTrackInfo,
                             preferredLanguages: [String] = Locale.preferredLanguages) -> SortKey {
    sortKey(lang: track.lang,
            typeId: track.typeId,
            typeTitle: track.typeTitle,
            typeShortTitle: track.typeShortTitle,
            author: track.authorTitle,
            channels: track.channels,
            isAudioDescription: track.isAudioDescription,
            index: track.index,
            preferredLanguages: preferredLanguages)
  }

  public static func sortKey(lang: String,
                             typeId: Int? = nil,
                             typeTitle: String? = nil,
                             typeShortTitle: String? = nil,
                             author: String? = nil,
                             channels: Int = 2,
                             isAudioDescription: Bool = false,
                             index: Int = 0,
                             preferredLanguages: [String] = Locale.preferredLanguages) -> SortKey {
    let (priority, alphaName) = languageSort(lang: lang, preferredLanguages: preferredLanguages)
    let studio = normalizedAuthor(author)
    return SortKey(languagePriority: priority,
                   languageName: alphaName,
                   isAudioDescription: isAudioDescription,
                   kindRank: kindRank(typeId: typeId, typeTitle: typeTitle, typeShortTitle: typeShortTitle),
                   hasAuthor: studio != nil,
                   authorName: studio?.lowercased() ?? "",
                   channels: channels,
                   index: index)
  }

  /// Ascending = preferred order for lists; the player's default is the first key.
  public struct SortKey: Comparable {
    public let languagePriority: Int
    public let languageName: String
    public let isAudioDescription: Bool
    public let kindRank: Int
    public let hasAuthor: Bool
    public let authorName: String
    public let channels: Int
    public let index: Int

    public static func < (l: SortKey, r: SortKey) -> Bool {
      if l.languagePriority != r.languagePriority { return l.languagePriority < r.languagePriority }
      if l.languageName != r.languageName { return l.languageName < r.languageName }
      if l.isAudioDescription != r.isAudioDescription { return !l.isAudioDescription && r.isAudioDescription }
      if l.kindRank != r.kindRank { return l.kindRank < r.kindRank }
      if l.hasAuthor != r.hasAuthor { return l.hasAuthor && !r.hasAuthor }
      if l.authorName != r.authorName { return l.authorName < r.authorName }
      if l.channels != r.channels { return l.channels > r.channels }
      return l.index < r.index
    }
  }

  // MARK: - Labels

  /// Sorted, human-facing labels. Same lang+type+author collapses to one row — the
  /// better rendition (more channels) is already first after `sort`.
  public static func descriptions(for tracks: [AudioTrackInfo],
                                  preferredLanguages: [String] = Locale.preferredLanguages) -> [String] {
    var seen = Set<String>()
    return sort(tracks, preferredLanguages: preferredLanguages).compactMap { track in
      let label = baseLabel(track)
      guard seen.insert(label).inserted else { return nil }
      return label
    }
  }

  /// One label per HLS AUDIO rendition, in playlist order. Consumes API tracks by
  /// language so the CDN's "Russian, Russian, Japanese" line up with the API rows.
  /// Duplicate labels get " · 2" etc. — HLS forbids identical NAME within a group.
  public static func labelsForHLSRenditions(languages: [String?],
                                            tracks: [AudioTrackInfo]) -> [String] {
    var queues: [String: [AudioTrackInfo]] = [:]
    for track in tracks {
      queues[SubtitleTracks.languageKey(track.lang), default: []].append(track)
    }

    let labels: [String] = languages.map { lang in
      let key = SubtitleTracks.languageKey(lang ?? "")
      if var queue = queues[key], !queue.isEmpty {
        let track = queue.removeFirst()
        queues[key] = queue
        return baseLabel(track)
      }
      if let lang, !lang.isEmpty {
        return LanguageNames.name(for: lang)
      }
      return "Audio"
    }
    return uniquedHLSLabels(labels)
  }

  public static func uniquedHLSLabels(_ labels: [String]) -> [String] {
    var totals: [String: Int] = [:]
    for label in labels { totals[label, default: 0] += 1 }
    var seen: [String: Int] = [:]
    return labels.map { label in
      guard totals[label, default: 0] > 1 else { return label }
      let n = seen[label, default: 0] + 1
      seen[label] = n
      return n == 1 ? label : "\(label) · \(n)"
    }
  }

  public static func baseLabel(_ track: AudioTrackInfo) -> String {
    var parts = [LanguageNames.name(for: track.lang)]
    if let type = track.typeTitle, !type.isEmpty {
      parts.append(type)
    }
    var line = parts.joined(separator: " — ")
    if let author = normalizedAuthor(track.authorTitle) {
      line += " (\(author))"
    }
    return line
  }

  // MARK: - Kind / language helpers

  /// Lower sorts earlier. Prefer the API type id when present.
  public static func kindRank(typeId: Int?, typeTitle: String?, typeShortTitle: String?) -> Int {
    if let typeId {
      switch typeId {
      case 1: return 0 // DUB
      case 2: return 1 // MVO
      case 3: return 2 // DVO
      case 4: return 3 // VO
      case 5: return 4 // AVO
      case 6: return 5 // Orig
      default: break
      }
    }
    let blob = [typeTitle, typeShortTitle].compactMap { $0 }.joined(separator: " ")
    if !blob.isEmpty { return kindRank(fromLabel: blob) }
    return kindRankUnknown
  }

  /// Parses kino.pub / HLS display names. AVO is checked before VO so "AVO" does not
  /// fall through as unknown.
  public static func kindRank(fromLabel label: String) -> Int {
    let name = label.lowercased()
    if name.contains("дубляж") || name.contains("дублир")
        || name.contains("dubbed") || containsToken(name, "dub") { return 0 }
    if name.contains("многоголос") || name.contains("multi")
        || containsToken(name, "mvo") { return 1 }
    if name.contains("двухголос") || name.contains("two")
        || containsToken(name, "dvo") { return 2 }
    if name.contains("авторск") || name.contains("author")
        || containsToken(name, "avo") { return 4 }
    if name.contains("одноголос") || name.contains("single")
        || containsToken(name, "ovo") || containsToken(name, "vo") { return 3 }
    if name.contains("оригинал") || name.contains("original")
        || containsToken(name, "orig") { return 5 }
    return kindRankUnknown
  }

  public static func looksLikeAudioDescription(_ title: String?) -> Bool {
    guard let title, !title.isEmpty else { return false }
    let name = title.lowercased()
    return name.contains("audio description")
      || name.contains("аудиоописание")
      || name.contains("описание")
      || containsToken(name, "ad")
  }

  /// Studio text inside trailing parentheses of an HLS option label, if any.
  public static func authorFromDisplayName(_ name: String) -> String? {
    guard let open = name.lastIndex(of: "("),
          let close = name[open...].firstIndex(of: ")"),
          open < close else { return nil }
    let inner = String(name[name.index(after: open)..<close])
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return inner.isEmpty ? nil : inner
  }

  public static func channelCount(fromLabel label: String) -> Int {
    let name = label.lowercased()
    if name.contains("7.1") { return 8 }
    if name.contains("5.1") { return 6 }
    if name.contains("2.0") || name.contains("стерео") || name.contains("stereo") { return 2 }
    if name.contains("mono") || name.contains("моно") { return 1 }
    return 2
  }

  // MARK: - Private

  private static func languageSort(lang: String,
                                   preferredLanguages: [String]) -> (priority: Int, name: String) {
    let key = SubtitleTracks.languageKey(lang)
    if let idx = preferredLanguages.firstIndex(where: { SubtitleTracks.languageKey($0) == key }) {
      return (idx, "")
    }
    let display = LanguageNames.name(for: lang).lowercased()
    return (preferredLanguages.count, display.isEmpty ? key : display)
  }

  private static func normalizedAuthor(_ author: String?) -> String? {
    guard let author else { return nil }
    let trimmed = author.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private static func containsToken(_ text: String, _ token: String) -> Bool {
    text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
      .contains { $0 == token }
  }
}
