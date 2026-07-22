//
//  SubtitleTrackMemory.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

/// What was picked mid-watch, kept per title so the next episode opens with it.
struct SubtitleChoice: Codable, Equatable {
  var primary: SubtitleTrackReference?
  var secondary: SubtitleTrackReference?

  /// A title watched with subtitles off is worth remembering too — otherwise the
  /// default preference turns them back on every episode.
  var isEmpty: Bool { primary == nil && secondary == nil }
}

/// `WatchingMetadata.id` is the series id for an episode, so the choice made on
/// episode 3 is the one episode 4 opens with.
enum SubtitleTrackMemory {
  private static let storageKey = "subtitleTrackChoices"

  static func choice(for itemID: Int, defaults: UserDefaults = .standard) -> SubtitleChoice? {
    stored(defaults)[String(itemID)]
  }

  static func remember(_ choice: SubtitleChoice, for itemID: Int, defaults: UserDefaults = .standard) {
    var choices = stored(defaults)
    choices[String(itemID)] = choice
    guard let data = try? JSONEncoder().encode(choices) else { return }
    defaults.set(data, forKey: storageKey)
  }

  static func forget(itemID: Int, defaults: UserDefaults = .standard) {
    var choices = stored(defaults)
    choices.removeValue(forKey: String(itemID))
    guard let data = try? JSONEncoder().encode(choices) else { return }
    defaults.set(data, forKey: storageKey)
  }

  private static func stored(_ defaults: UserDefaults) -> [String: SubtitleChoice] {
    guard let data = defaults.data(forKey: storageKey),
          let choices = try? JSONDecoder().decode([String: SubtitleChoice].self, from: data) else {
      return [:]
    }
    return choices
  }
}
