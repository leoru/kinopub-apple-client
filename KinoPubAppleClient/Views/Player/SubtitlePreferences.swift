//
//  SubtitlePreferences.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import MediaAccessibility

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

extension PlaybackLanguagePreferences {

  static let audioLanguagesKey = "preferredAudioLanguages"
  static let subtitleLanguagesKey = "preferredSubtitleLanguages"
  static let minimumDubKindKey = "minimumDubKind"
  static let subtitlesDefaultOnKey = "subtitlesDefaultOn"
  static let subtitlesForForeignAudioKey = "subtitlesForForeignAudio"
  static let animeOriginalAudioKey = "animePrefersOriginalAudio"

  /// `minimumDubKind` when the viewer has set no floor.
  static let noDubFloor = -1

  /// The language ladder as the viewer has it. Empty lists mean "mirror the system",
  /// which is the default and covers anyone who never opens Settings.
  static var current: PlaybackLanguagePreferences {
    let defaults = UserDefaults.standard
    var subtitleLanguages = defaults.stringArray(forKey: subtitleLanguagesKey) ?? []
    if subtitleLanguages.isEmpty { subtitleLanguages = systemCaptionLanguages }
    // "Default English subtitles" says which language wins, not whether subtitles appear —
    // that is `subtitlesDefaultOn`, which the system already answers.
    if SubtitlePreferences.preferEnglishSubtitles, !subtitleLanguages.contains("en") {
      subtitleLanguages.insert("en", at: 0)
    }
    return PlaybackLanguagePreferences(
      audioLanguages: defaults.stringArray(forKey: audioLanguagesKey) ?? [],
      subtitleLanguages: subtitleLanguages,
      // Stored as an Int because `@AppStorage` has no Int? — negative means "no floor",
      // which is also what a missing key means.
      minimumDubKind: (defaults.object(forKey: minimumDubKindKey) as? Int).flatMap { $0 < 0 ? nil : $0 },
      subtitlesDefaultOn: defaults.object(forKey: subtitlesDefaultOnKey) as? Bool
        ?? systemWantsCaptions,
      subtitlesWhenAudioNotUnderstood: defaults.object(forKey: subtitlesForForeignAudioKey) == nil
        ? true
        : defaults.bool(forKey: subtitlesForForeignAudioKey),
      animePrefersOriginalAudio: defaults.bool(forKey: animeOriginalAudioKey),
      preferNonCCSubtitles: SubtitlePreferences.preferNonCCSubtitles
    )
  }

  /// **Where the viewer already answered "do I watch with subtitles".** Settings →
  /// Accessibility → Subtitles & Captioning, read through `MediaAccessibility`. Answering
  /// it a second time in our own Settings, with its own default, is how an app ends up
  /// disagreeing with the rest of the system about the same preference.
  ///
  /// `.alwaysOn` is the only value that means "on". `.automatic` is the stock default and
  /// means "let the content decide", which for us is the foreign-audio rule below.
  static var systemWantsCaptions: Bool {
    MACaptionAppearanceGetDisplayType(.user) == .alwaysOn
  }

  /// The caption languages chosen in the same place, most preferred first.
  static var systemCaptionLanguages: [String] {
    // Non-optional `Unmanaged<CFArray>`, so there is nothing to bind — take the value and
    // let the bridge cast decide whether it holds strings.
    let copied = MACaptionAppearanceCopySelectedLanguages(.user).takeRetainedValue()
    return (copied as NSArray) as? [String] ?? []
  }
}
