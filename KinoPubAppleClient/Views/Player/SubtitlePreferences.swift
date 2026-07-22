//
//  SubtitlePreferences.swift
//  KinoPubAppleClient
//

import Foundation

enum SubtitlePreferences {
  static let preferEnglishKey = "preferEnglishSubtitles"
  static let preferNonCCKey = "preferNonCCSubtitles"
  static let dualSubtitlesKey = "dualSubtitlesEnabled"
  static let secondSubtitleLanguageKey = "secondSubtitleLanguage"

  /// Languages offered as the second track. The first one is whatever the item is
  /// being watched in — usually English.
  static let secondLanguageOptions = ["ru", "en", "uk", "de", "fr", "es"]

  static var preferEnglishSubtitles: Bool {
    boolValue(forKey: preferEnglishKey, default: true)
  }

  static var preferNonCCSubtitles: Bool {
    boolValue(forKey: preferNonCCKey, default: true)
  }

  /// Off by default: two lines of text is a deliberate choice, not something to wake
  /// up to.
  static var dualSubtitlesEnabled: Bool {
    boolValue(forKey: dualSubtitlesKey, default: false)
  }

  static var secondSubtitleLanguage: String {
    UserDefaults.standard.string(forKey: secondSubtitleLanguageKey) ?? "ru"
  }

  private static func boolValue(forKey key: String, default fallback: Bool) -> Bool {
    guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
    return UserDefaults.standard.bool(forKey: key)
  }
}
