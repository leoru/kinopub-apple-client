//
//  AppFeatures.swift
//  KinoPubAppleClient
//

import Foundation

/// Central on/off switches for incomplete or optional surfaces. Same pattern as
/// `SubtitlePreferences`: UserDefaults keys + static readers for non-View call
/// sites, `@AppStorage` bindings in Settings for live toggles.
///
/// Add new gated work here rather than scattering `#if` / hard-coded hides.
/// An off flag must skip the work (network, sampling, chrome), not only the UI.
enum AppFeatures {
  static let homeBannerKey = "feature.homeBanner"
  static let downloadsKey = "feature.downloads"

  /// Contained Home banner shelf. Off by default — the v1 shelf samples catalog
  /// rows and kicks off wide-poster loads; keep the code, turn it on from
  /// Settings → Features when you want it back.
  static var homeBannerEnabled: Bool {
    boolValue(forKey: homeBannerKey, default: false)
  }

  /// Downloads tab and related chrome. Always off on tvOS (no offline story).
  /// Elsewhere on by default; one switch hides the whole surface.
  static var downloadsEnabled: Bool {
#if os(tvOS)
    false
#else
    boolValue(forKey: downloadsKey, default: true)
#endif
  }

  private static func boolValue(forKey key: String, default fallback: Bool) -> Bool {
    guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
    return UserDefaults.standard.bool(forKey: key)
  }
}
