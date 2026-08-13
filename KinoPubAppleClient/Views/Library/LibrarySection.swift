//
//  LibrarySection.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

/// One entry of the Library sidebar. Sections are the *destinations* of the Library
/// tab — each shows its own vertical poster grid, none of them is a shelf row.
///
/// Order and membership are a product decision, not an implementation detail:
/// see `ROADMAP.md`.
///
/// `folder` carries only the id on purpose. A `Bookmark` value changes whenever its
/// item count or `updated` stamp does, so selecting on the whole model would drop the
/// user's selection every time the folder list refreshes. Titles and counts come from
/// `LibraryModel.folders` at draw time.
enum LibrarySection: Hashable, Codable {
  case watchlist
  case movies
  case history
  case downloads
  case folder(Int)

  /// The fixed sections, in sidebar order. Bookmark folders follow, from `LibraryModel`.
  ///
  /// Downloads is behind `FeatureFlags.downloadsEnabled` like every other downloads
  /// entry point — an off flag drops the row entirely, it does not show a dead one.
  static var fixed: [LibrarySection] {
    var sections: [LibrarySection] = [.watchlist, .movies, .history]
    if FeatureFlags.downloadsEnabled {
      sections.append(.downloads)
    }
    return sections
  }

  var systemImage: String {
    switch self {
    case .watchlist: return "star"
    case .movies: return "movieclapper"
    case .history: return "clock"
    case .downloads: return "arrow.down.circle"
    case .folder: return "bookmark"
    }
  }

  /// Title for everything but folders — a folder's title is whatever the user named
  /// it, so it comes from `LibraryModel.title(for:)`.
  var fixedTitle: String? {
    switch self {
    case .watchlist: return "Watchlist".localized
    case .movies: return "Movies".localized
    case .history: return "Recently Watched".localized
    case .downloads: return "Downloads".localized
    case .folder: return nil
    }
  }

  /// Where this section's first page lives in `ContentStore`. `nil` for Downloads —
  /// those are local files owned by `DownloadsCatalog`, nothing to cache from network.
  var rowKey: RowKey? {
    switch self {
    case .watchlist: return .watchlist
    case .movies: return .watchingMovies
    case .history: return .history
    case .downloads: return nil
    case .folder(let id): return .folder(id)
    }
  }

  /// History and folder contents keep paging; the watching endpoints answer in one shot.
  var isPaginated: Bool {
    switch self {
    case .history, .folder: return true
    case .watchlist, .movies, .downloads: return false
    }
  }

  /// Downloads is drawn by the existing `DownloadsView`, not by `LibrarySectionCatalog`.
  var usesCardGrid: Bool {
    self != .downloads
  }

  // MARK: - Persistence

  /// Stable string for remembering the last selection across launches. Must not
  /// encode anything that changes with a refresh.
  var persistenceID: String {
    switch self {
    case .watchlist: return "watchlist"
    case .movies: return "movies"
    case .history: return "history"
    case .downloads: return "downloads"
    case .folder(let id): return "folder:\(id)"
    }
  }

  init?(persistenceID: String) {
    switch persistenceID {
    case "watchlist": self = .watchlist
    case "movies": self = .movies
    case "history": self = .history
    case "downloads": self = .downloads
    default:
      guard persistenceID.hasPrefix("folder:"),
            let id = Int(persistenceID.dropFirst("folder:".count)) else { return nil }
      self = .folder(id)
    }
  }
}
