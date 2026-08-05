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
  /// Unfinished films — `/v1/watching/movies`. Separate from `watchlist` because the
  /// Library sidebar shows them as their own section (kino.pub's "Недосмотренные").
  case watchingMovies
  case history
  case folder(Int)
  /// Home's "Collections" preview row — a handful of curated collection covers.
  /// The full browser is a paginated cover grid and does not go through the store.
  case collections

  /// Group for prefix invalidation: clearing history shouldn't blow away catalog
  /// shelves, and toggling a bookmark shouldn't touch continue-watching.
  enum Family {
    case watch
    case catalog
    case bookmarks
  }

  var family: Family {
    switch self {
    case .continueWatching, .history, .watchlist, .watchingMovies: return .watch
    case .shortcut, .collections: return .catalog
    case .folder: return .bookmarks
    }
  }

  /// How long a cached row is trusted before a background refresh is worth doing.
  /// Continue watching/history change after every session; catalog shelves barely
  /// change at all.
  var ttl: TimeInterval {
    switch self {
    case .continueWatching, .history: return 60
    case .watchlist, .watchingMovies: return 120
    case .shortcut, .collections: return 15 * 60
    case .folder: return 10 * 60
    }
  }
}
