//
//  HistoryEntry.swift
//
//

import Foundation

/// One row of `/v1/history`. Only the fields needed to order "continue watching" are
/// decoded — the endpoint returns far more per entry.
public struct HistoryEntry: Codable, Hashable {

  public struct Item: Codable, Hashable {
    public let id: Int
  }

  public let item: Item
  public let lastSeen: Int?
  public let firstSeen: Int?

  private enum CodingKeys: String, CodingKey {
    case item
    case lastSeen = "last_seen"
    case firstSeen = "first_seen"
  }

  public init(item: Item, lastSeen: Int?, firstSeen: Int? = nil) {
    self.item = item
    self.lastSeen = lastSeen
    self.firstSeen = firstSeen
  }
}

public extension HistoryEntry {
  var lastSeenDate: Date? {
    guard let lastSeen, lastSeen > 0 else { return nil }
    return Date(timeIntervalSince1970: TimeInterval(lastSeen))
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
