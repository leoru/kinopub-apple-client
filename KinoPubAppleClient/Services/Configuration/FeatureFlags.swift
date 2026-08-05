//
//  FeatureFlags.swift
//  KinoPubAppleClient
//

import Foundation

/// Single source of truth for user-facing surfaces that are compiled but not yet
/// ready to ship. Flip one flag instead of scattering per-view checks.
///
/// An off flag must skip the work (network, sampling, chrome), not only hide UI.
enum FeatureFlags {
  /// Contained Home banner shelf. Off pending redesign — when false, Home does
  /// not sample banner cards and does not load wide poster artwork for them.
  static let homeBannerEnabled = false

  /// Gates the Downloads tab, the item-detail download action, and any other
  /// downloads-facing UI. `KinoPubKit`'s `DownloadManager` / `DownloadedFilesDatabase`
  /// machinery stays compiled and available either way — this only hides entry points.
  ///
  /// TODO(downloads): when this flips on, add Download to `MediaCardContextMenus`
  /// (single source — do not hand-roll per shelf / banner / rail).
  static let downloadsEnabled = false

  /// "All Bookmarks" overview tab (folder shelves). Off while History / Watchlist /
  /// per-folder tabs carry browsing; when false the tab is omitted and the overview
  /// catalog is not fetched.
  static let allBookmarksEnabled = false

  /// tvOS shelves + grids share one `TVPosterView` / `TVCardView` atom (same
  /// `ShelfMetrics` sizing). Off until Device Hub focus validation; SwiftUI
  /// `MediaCardView` remains the fallback. iOS / macOS ignore this flag.
  static let tvUIKitPosters = false
}
