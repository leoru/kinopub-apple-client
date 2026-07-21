//
//  ContinueWatchingOrder.swift
//
//

import Foundation

/// Ordering rules for the home screen's "continue watching" row.
public enum ContinueWatchingOrder {

  /// How recently something must have been played to count as "picked up lately".
  public static let recentWindow: TimeInterval = 7 * 24 * 60 * 60

  public enum Bucket: Int {
    /// Not on the watchlist but played within the last week — picked up on a whim
    /// and the easiest to forget about, so it leads.
    case recentAside = 0
    /// The watchlist proper.
    case watchlist = 1
    /// Everything else still unfinished.
    case rest = 2
  }

  public static func bucket(for item: WatchingItem,
                            watchlistIDs: Set<Int>,
                            lastSeen: [Int: Date],
                            now: Date) -> Bucket {
    let onWatchlist = watchlistIDs.contains(item.id)
    if !onWatchlist,
       let seen = lastSeen[item.id],
       now.timeIntervalSince(seen) <= recentWindow,
       now >= seen {
      return .recentAside
    }
    return onWatchlist ? .watchlist : .rest
  }

  /// Sorts by bucket, then most recently played first. Titles with no history sink to
  /// the bottom of their bucket, keeping the API's own order as the final tiebreak.
  public static func ordered(items: [WatchingItem],
                             watchlistIDs: Set<Int>,
                             lastSeen: [Int: Date],
                             now: Date = Date()) -> [WatchingItem] {
    items.enumerated().sorted { lhs, rhs in
      let lhsBucket = bucket(for: lhs.element, watchlistIDs: watchlistIDs, lastSeen: lastSeen, now: now)
      let rhsBucket = bucket(for: rhs.element, watchlistIDs: watchlistIDs, lastSeen: lastSeen, now: now)
      if lhsBucket != rhsBucket { return lhsBucket.rawValue < rhsBucket.rawValue }

      switch (lastSeen[lhs.element.id], lastSeen[rhs.element.id]) {
      case let (l?, r?) where l != r: return l > r
      case (nil, .some): return false
      case (.some, nil): return true
      default: return lhs.offset < rhs.offset
      }
    }.map(\.element)
  }

  /// History has a row per episode; collapse it to the newest play per title.
  public static func lastSeenByItemID(_ history: [HistoryEntry]) -> [Int: Date] {
    history.reduce(into: [Int: Date]()) { result, entry in
      guard let date = entry.lastSeenDate else { return }
      if let existing = result[entry.item.id], existing >= date { return }
      result[entry.item.id] = date
    }
  }
}
