//
//  FeatureFlags.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubUI

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
  /// `ShelfMetrics` sizing), drawn by a recycling `UICollectionView` rather than a
  /// Lazy stack — lazy defers creation, it does not reuse cells. SwiftUI
  /// `MediaCardView` remains the fallback. iOS / macOS ignore this flag.
  ///
  /// On since 2026-08-06. **Device Hub focus validation is still outstanding** — this
  /// was turned on to be judged on a real screen, not because that check passed.
  static let tvUIKitPosters = true

  /// Our own combined IMDb + Kinopoisk score: poster plaque, hero pill, the detail
  /// "Rating" tile, and the card Rating placement / source settings. Off — IMDb and
  /// Kinopoisk show only under their own logos meanwhile.
  ///
  /// The value itself lives in `KinoPubUI.RatingFeature` because card chrome reads it
  /// from inside the package. This is the app-side alias, not a second switch.
  static var combinedRatingEnabled: Bool { RatingFeature.combinedEnabled }

  /// **TEMPORARY DIAGNOSTIC — DELETE ME.** Synthesises a fake season of episodes onto
  /// *movies*, so the detail page's season rail renders for a title that has none.
  ///
  /// Exists to test one specific hypothesis: that the hero blur / scroll choreography
  /// only behaves because a season rail happens to be the first section below the hero,
  /// and falls apart for movies where it is absent. Comparing a movie with and without
  /// this flag isolates "is it the content or the choreography".
  ///
  /// The fabricated episodes are **not playable** (no `files`) — this is a layout and
  /// focus probe, nothing else. DEBUG-only so it cannot reach a shipping build.
#if DEBUG
  static let fakeSeasonsOnMovies = false
#else
  static let fakeSeasonsOnMovies = false
#endif
}

/// Defaults keys shared by the diagnostics surfaces, so a toggle and the thing it
/// toggles cannot drift apart. The "Verbose logging" switch this replaces was bound to a
/// `@State` nothing read, under the footer "Demo controls — not saved yet" — a control
/// that does nothing is worse than no control, because it looks like an answer.
enum DiagnosticsSettings {
  /// Shows the in-flight network readout over the whole app.
  static let activityOverlayKey = "diagnostics.activityOverlay"

  /// Streams the network log to the Pulse app on a Mac. Off by default — turning it on
  /// is what asks for local-network permission, and that prompt is the user's to spend.
  static let remoteLoggingKey = "diagnostics.remoteLogging"
}
