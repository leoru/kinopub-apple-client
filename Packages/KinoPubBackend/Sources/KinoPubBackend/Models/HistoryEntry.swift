//
//  HistoryEntry.swift
//
//

import Foundation

/// One row of `/v1/history`. Everything beyond the item id is optional: this drives
/// presentation only, and one malformed row must not cost us the whole response.
public struct HistoryEntry: Codable, Hashable {

  /// The title the entry belongs to. Unlike `/v1/watching/*`, history carries the
  /// wide poster, which is what a landscape card needs.
  public struct Item: Codable, Hashable {
    public let id: Int
    public let type: String?
    public let title: String?
    public let posters: Posters?

    public init(id: Int, type: String? = nil, title: String? = nil, posters: Posters? = nil) {
      self.id = id
      self.type = type
      self.title = title
      self.posters = posters
    }
  }

  /// The specific video played — an episode for a series, the film itself otherwise.
  public struct Media: Codable, Hashable {
    public let id: Int?
    /// Episode number.
    public let number: Int?
    /// Season number.
    public let snumber: Int?
    public let title: String?
    /// Landscape still, the image Apple TV shows for continue-watching.
    public let thumbnail: String?
    /// Runtime in seconds.
    public let duration: Int?

    public init(id: Int? = nil,
                number: Int? = nil,
                snumber: Int? = nil,
                title: String? = nil,
                thumbnail: String? = nil,
                duration: Int? = nil) {
      self.id = id
      self.number = number
      self.snumber = snumber
      self.title = title
      self.thumbnail = thumbnail
      self.duration = duration
    }
  }

  public let item: Item
  public let media: Media?
  /// Where playback stopped, in seconds.
  public let time: Double?
  public let lastSeen: Int?
  public let firstSeen: Int?

  private enum CodingKeys: String, CodingKey {
    case item
    case media
    case time
    case lastSeen = "last_seen"
    case firstSeen = "first_seen"
  }

  public init(item: Item, media: Media? = nil, time: Double? = nil, lastSeen: Int?, firstSeen: Int? = nil) {
    self.item = item
    self.media = media
    self.time = time
    self.lastSeen = lastSeen
    self.firstSeen = firstSeen
  }
}

public extension HistoryEntry {
  var lastSeenDate: Date? {
    guard let lastSeen, lastSeen > 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(lastSeen))
  }

  /// How far into this video the user got, or nil when it can't be worked out / is finished.
  var progress: Double? {
    guard let time, let duration = media?.duration else { return nil }
    let watch = WatchProgress(position: time, duration: Double(duration))
    return watch.resumeFraction
  }

  /// Shared classifier for this history row (live / trailer / unfinished / finished).
  var watchProgress: WatchProgress? {
    guard let time, let duration = media?.duration else { return nil }
    return WatchProgress(position: time, duration: Double(duration))
  }

  /// True when the entry refers to an episode rather than a film. Films come back
  /// with `snumber` 0 and `number` 1, which must not render as "S0, E1".
  var isEpisode: Bool {
    guard let season = media?.snumber, let number = media?.number else { return false }
    return season > 0 && number > 0
  }
}

/// `/v1/history` wraps its rows in a `history` key rather than the usual `items`.
public struct HistoryData: Codable {
  public let history: [HistoryEntry]
  public let pagination: Pagination?

  public static func mock(data: [HistoryEntry]) -> HistoryData {
    HistoryData(history: data, pagination: nil)
  }
}
