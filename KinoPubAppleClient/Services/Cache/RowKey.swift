//
//  RowKey.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

/// Identifies one cacheable row of cards in `ContentStore` — Home shortcuts, the
/// Library's watchlist/history/folders. Not used for paginated grids (Movies/Series/
/// Search tabs) yet; those still fetch page-by-page through `MediaCatalog`.
enum RowKey: Hashable, Codable {
  case continueWatching
  case shortcut(MediaShortcut, MediaType)
  case watchlist
  case history
  case folder(Int)

  /// Group for prefix invalidation: clearing history shouldn't blow away catalog
  /// shelves, and toggling a bookmark shouldn't touch continue-watching.
  enum Family {
    case watch
    case catalog
    case bookmarks
  }

  var family: Family {
    switch self {
    case .continueWatching, .history, .watchlist: return .watch
    case .shortcut: return .catalog
    case .folder: return .bookmarks
    }
  }

  /// How long a cached row is trusted before a background refresh is worth doing.
  /// Continue watching/history change after every session; catalog shelves barely
  /// change at all.
  var ttl: TimeInterval {
    switch self {
    case .continueWatching, .history: return 60
    case .watchlist: return 120
    case .shortcut: return 15 * 60
    case .folder: return 10 * 60
    }
  }
}
