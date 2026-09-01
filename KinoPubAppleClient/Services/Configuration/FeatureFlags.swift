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

  /// A series detail page fetches its item with `nolinks=1` and resolves an episode's
  /// links from `/v1/items/media-links` when it is played (`MediaLinksResolver`).
  ///
  /// **Off.** It saves real bytes on a long show — most of that payload is links, and at
  /// most one episode's worth is ever used — but every playback path has to go and get a
  /// link first, and the first attempt shipped with a decoder that could not read a
  /// link-less `files` entry at all, so every series page said "Couldn't Load". The
  /// machinery stays compiled and switchable; kino.pub is making `nolinks=1` the default
  /// in a future API version, so this is what we flip when that lands — after watching a
  /// series actually play with it on.
  static let seriesDetailsWithoutLinks = false

  /// The muted trailer that starts by itself behind the detail hero (macOS today —
  /// iPhone is off for legibility, tvOS by the no-blur-over-video policy).
  ///
  /// Off means no second `AVPlayer` is ever built and no trailer stream is fetched, not
  /// a hidden video layer. Up-to-fullscreen then has nothing to open, and the Trailer
  /// button still plays the real thing through the system player.
  static let heroAmbientTrailerEnabled = false

  /// The artwork behind a detail page: the blurred-poster wash on iOS / macOS, and on
  /// tvOS the full-bleed hero still with its fold material.
  ///
  /// Off means the page sits on the plain app background and neither the wide still nor
  /// the blur buffer is decoded — the hero's own foreground (title, actions, poster) is
  /// untouched. **On tvOS that is the whole picture behind the page**, so expect a bare
  /// page there, not a subtler one.
  static let detailAmbientBackdropEnabled = false

  /// The tvOS sidecar-SRT machinery: a custom transport-bar Subtitles menu (dual
  /// tracks), our own cue overlay, and hiding the system's Subtitles control.
  ///
  /// **Off.** Subtitles are the system player's on every platform — the master's own
  /// WebVTT renditions, styled by the system. The machinery stays compiled because the
  /// dual-subtitle stage will want it; flipping this brings the whole path back.
  static let tvOSSidecarSubtitles = false

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
