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
  static let downloadsEnabled = false
}
