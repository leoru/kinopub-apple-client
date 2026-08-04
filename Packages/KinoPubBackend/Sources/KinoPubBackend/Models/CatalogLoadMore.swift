//
//  CatalogLoadMore.swift
//
//

import Foundation

/// Shared "scrolled to last loaded card" check for paginated catalog grids.
///
/// Call sites must use this (or an equivalent `item.id == items.last?.id` check)
/// rather than `items.firstIndex(of: item)`. `MediaItem`'s synthesized `==` walks
/// nested arrays (seasons, videos, cast, …), so a linear `firstIndex` from every
/// card's `.onAppear` is O(n²) deep comparisons on the main thread.
public enum CatalogLoadMore {
  public static func isThresholdItem(_ item: MediaItem, in items: [MediaItem]) -> Bool {
    isThresholdID(item.id, lastID: items.last?.id)
  }

  /// Same last-card check for `MediaCard` grids (History / Watchlist).
  public static func isThresholdID(_ id: Int, lastID: Int?) -> Bool {
    id == lastID
  }
}
