//
//  MediaCardDisplayPreferences.swift
//  KinoPubUI
//
//  UserDefaults-backed chrome for poster / landscape cards. Settings → Appearance
//  writes these keys; MediaCardView reads them via @AppStorage / static getters.
//

import Foundation

/// Where a chip or score sits relative to the artwork.
public enum MediaCardChromePlacement: String, CaseIterable, Identifiable, Sendable {
  case onArtwork
  case inCaption
  case hidden

  public var id: String { rawValue }

  public var titleKey: String {
    switch self {
    case .onArtwork: return "On poster"
    case .inCaption: return "Under title"
    case .hidden: return "Hidden"
    }
  }
}

/// Which score feeds the rating plaque / caption.
public enum MediaCardRatingSource: String, CaseIterable, Identifiable, Sendable {
  case combined
  case imdb
  case kinopoisk

  public var id: String { rawValue }

  public var titleKey: String {
    switch self {
    case .combined: return "Combined"
    case .imdb: return "IMDb"
    case .kinopoisk: return "Kinopoisk"
    }
  }
}

/// How a fully watched title is marked on a vertical poster.
public enum MediaCardWatchedStyle: String, CaseIterable, Identifiable, Sendable {
  case dim
  case checkmark
  case dimAndCheckmark
  case hidden

  public var id: String { rawValue }

  public var titleKey: String {
    switch self {
    case .dim: return "Dim artwork"
    case .checkmark: return "Checkmark"
    case .dimAndCheckmark: return "Dim + checkmark"
    case .hidden: return "None"
    }
  }

  public var dimsArtwork: Bool {
    self == .dim || self == .dimAndCheckmark
  }

  public var showsCheckmark: Bool {
    self == .checkmark || self == .dimAndCheckmark
  }
}

/// When the resume progress bar is drawn on card artwork.
public enum MediaCardProgressVisibility: String, CaseIterable, Identifiable, Sendable {
  case always
  case onFocusHover

  public var id: String { rawValue }

  public var titleKey: String {
    switch self {
    case .always: return "Always"
    case .onFocusHover: return "On hover / focus"
    }
  }
}

/// Catalog / shelf card chrome preferences.
public enum MediaCardDisplayPreferences {

  // MARK: Keys

  public static let ratingPlacementKey = "card.ratingPlacement"
  public static let ratingSourceKey = "card.ratingSource"
  public static let capabilityPlacementKey = "card.capabilityPlacement"
  public static let show4KKey = "card.show4K"
  public static let showHDRKey = "card.showHDR"
  public static let showHDKey = "card.showHD"
  public static let show3DKey = "card.show3D"
  public static let showCCKey = "card.showCC"
  public static let editorialPlacementKey = "card.editorialPlacement"
  public static let showOriginalTitleKey = "card.showOriginalTitle"
  public static let showYearKey = "card.showYear"
  public static let showDurationKey = "card.showDuration"
  public static let showGenreKey = "card.showGenre"
  public static let showCountryKey = "card.showCountry"
  public static let showBookmarkSymbolKey = "card.showBookmarkSymbol"
  public static let progressVisibilityKey = "card.progressVisibility"
  public static let watchedStyleKey = "card.watchedStyle"

  /// Legacy bool key — migrated once into `progressVisibilityKey`.
  public static let showProgressBarKey = "card.showProgressBar"

  // MARK: Defaults (match shipping chrome before prefs existed)

  public static let defaultRatingPlacement: MediaCardChromePlacement = .onArtwork
  public static let defaultRatingSource: MediaCardRatingSource = .combined
  public static let defaultCapabilityPlacement: MediaCardChromePlacement = .onArtwork
  public static let defaultShow4K = true
  public static let defaultShowHDR = false
  public static let defaultShowHD = false
  public static let defaultShow3D = false
  public static let defaultShowCC = false
  public static let defaultEditorialPlacement: MediaCardChromePlacement = .onArtwork
  public static let defaultShowOriginalTitle = false
  public static let defaultShowYear = false
  public static let defaultShowDuration = true
  public static let defaultShowGenre = false
  public static let defaultShowCountry = false
  public static let defaultShowBookmarkSymbol = true
  public static let defaultProgressVisibility: MediaCardProgressVisibility = .always
  public static let defaultWatchedStyle: MediaCardWatchedStyle = .dim

  // MARK: Readers (non-View call sites)

  public static var ratingPlacement: MediaCardChromePlacement {
    placement(forKey: ratingPlacementKey, default: defaultRatingPlacement)
  }

  public static var ratingSource: MediaCardRatingSource {
    if let raw = UserDefaults.standard.string(forKey: ratingSourceKey),
       let value = MediaCardRatingSource(rawValue: raw) {
      return value
    }
    return defaultRatingSource
  }

  public static var capabilityPlacement: MediaCardChromePlacement {
    placement(forKey: capabilityPlacementKey, default: defaultCapabilityPlacement)
  }

  public static var show4K: Bool { bool(forKey: show4KKey, default: defaultShow4K) }
  public static var showHDR: Bool { bool(forKey: showHDRKey, default: defaultShowHDR) }
  public static var showHD: Bool { bool(forKey: showHDKey, default: defaultShowHD) }
  public static var show3D: Bool { bool(forKey: show3DKey, default: defaultShow3D) }
  public static var showCC: Bool { bool(forKey: showCCKey, default: defaultShowCC) }

  public static var editorialPlacement: MediaCardChromePlacement {
    placement(forKey: editorialPlacementKey, default: defaultEditorialPlacement)
  }

  public static var showOriginalTitle: Bool {
    bool(forKey: showOriginalTitleKey, default: defaultShowOriginalTitle)
  }
  public static var showYear: Bool { bool(forKey: showYearKey, default: defaultShowYear) }
  public static var showDuration: Bool {
    bool(forKey: showDurationKey, default: defaultShowDuration)
  }
  public static var showGenre: Bool { bool(forKey: showGenreKey, default: defaultShowGenre) }
  public static var showCountry: Bool {
    bool(forKey: showCountryKey, default: defaultShowCountry)
  }
  public static var showBookmarkSymbol: Bool {
    bool(forKey: showBookmarkSymbolKey, default: defaultShowBookmarkSymbol)
  }

  public static var progressVisibility: MediaCardProgressVisibility {
    if let raw = UserDefaults.standard.string(forKey: progressVisibilityKey),
       let value = MediaCardProgressVisibility(rawValue: raw) {
      return value
    }
    // One-shot migrate from the old on/off toggle.
    if let legacy = UserDefaults.standard.object(forKey: showProgressBarKey) as? Bool {
      return legacy ? .always : .onFocusHover
    }
    return defaultProgressVisibility
  }

  public static var watchedStyle: MediaCardWatchedStyle {
    if let raw = UserDefaults.standard.string(forKey: watchedStyleKey),
       let value = MediaCardWatchedStyle(rawValue: raw) {
      return value
    }
    return defaultWatchedStyle
  }

  private static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
    UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
  }

  private static func placement(forKey key: String,
                                default defaultValue: MediaCardChromePlacement)
  -> MediaCardChromePlacement {
    if let raw = UserDefaults.standard.string(forKey: key),
       let value = MediaCardChromePlacement(rawValue: raw) {
      return value
    }
    return defaultValue
  }
}
