//
//  WatchingItem.swift
//
//

import Foundation

/// The trimmed-down item shape returned by `/v1/watching/movies` and
/// `/v1/watching/serials`. These endpoints send only enough to draw a card, so this
/// deliberately is not a `MediaItem` — decoding one from this payload would fail.
public struct WatchingItem: Codable, Hashable, Identifiable {
  public let id: Int
  public let type: String
  public let subtype: String?
  public let title: String
  public let posters: Posters

  /// Serials only: total episodes, how many have been watched, and how many are new.
  public let total: Int?
  public let watched: Int?
  public let new: Int?

  public init(id: Int,
              type: String,
              subtype: String? = nil,
              title: String,
              posters: Posters,
              total: Int? = nil,
              watched: Int? = nil,
              new: Int? = nil) {
    self.id = id
    self.type = type
    self.subtype = subtype
    self.title = title
    self.posters = posters
    self.total = total
    self.watched = watched
    self.new = new
  }
}

public extension WatchingItem {
  /// kino.pub titles are "Локализованное / Original"; cards show them on two lines.
  var localizedTitle: String {
    title.split(separator: "/").first?.trimmingCharacters(in: .whitespaces) ?? title
  }

  var originalTitle: String {
    title.split(separator: "/").last?.trimmingCharacters(in: .whitespaces) ?? title
  }

  /// How far through a serial the user is, or nil for movies.
  var progress: Double? {
    guard let total, total > 0, let watched else { return nil }
    return min(Double(watched) / Double(total), 1.0)
  }

  var hasNewEpisodes: Bool {
    (new ?? 0) > 0
  }
}

public extension WatchingItem {
  static func mock(id: Int = 1, title: String = "Тестовый / Test", new: Int? = nil) -> WatchingItem {
    WatchingItem(id: id,
                 type: "serial",
                 subtype: "",
                 title: title,
                 posters: Posters(small: "", medium: "", big: "", wide: nil),
                 total: 10,
                 watched: 5,
                 new: new)
  }

  /// A recently-played title that only showed up in `/v1/history`, so Continue
  /// Watching can still put it in the "recently started" bucket.
  init?(historyEntry entry: HistoryEntry) {
    guard let posters = entry.item.posters else { return nil }
    self.init(id: entry.item.id,
              type: entry.item.type ?? "movie",
              title: entry.item.title ?? "",
              posters: posters)
  }

  /// Local resume point whose `MediaItem` snapshot is enough to draw a Continue Watching card
  /// before/without the backend listing the title.
  init(mediaItem: MediaItem) {
    self.init(id: mediaItem.id,
              type: mediaItem.type,
              subtype: mediaItem.subtype,
              title: mediaItem.title,
              posters: mediaItem.posters)
  }
}
