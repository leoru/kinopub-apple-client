//
//  MediaItemDisplayPreferences.swift
//  KinoPubAppleClient
//

import Foundation

/// What the item page volunteers over the artwork. Chrome that is genuinely useful to
/// some people and noise to everyone else lives here rather than being shown to all.
enum MediaItemDisplayPreferences {

  static let showAgeRatingBadgeKey = "showAgeRatingBadge"

  /// Off. A certification tells a viewer who already chose to open the page nothing
  /// they were looking for, and it costs the metadata row a chip. It stays available
  /// in the information table further down, and the badge can be switched back on in
  /// Settings for anyone who is filtering by it.
  static var showAgeRatingBadge: Bool {
    UserDefaults.standard.object(forKey: showAgeRatingBadgeKey) as? Bool ?? false
  }
}
