//
//  SubtitlePreferences.swift
//  KinoPubAppleClient
//

import Foundation

enum SubtitlePreferences {
  static let preferEnglishKey = "preferEnglishSubtitles"
  static let preferNonCCKey = "preferNonCCSubtitles"

  static var preferEnglishSubtitles: Bool {
    if UserDefaults.standard.object(forKey: preferEnglishKey) == nil {
      return true
    }
    return UserDefaults.standard.bool(forKey: preferEnglishKey)
  }

  static var preferNonCCSubtitles: Bool {
    if UserDefaults.standard.object(forKey: preferNonCCKey) == nil {
      return true
    }
    return UserDefaults.standard.bool(forKey: preferNonCCKey)
  }
}
