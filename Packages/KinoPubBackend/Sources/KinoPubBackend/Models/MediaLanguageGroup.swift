//
//  MediaLanguageGroup.swift
//

import Foundation

/// One language on the detail page: a semibold title and the kind/studio lines under it.
public struct MediaLanguageGroup: Hashable, Identifiable {
  public var id: String { key }
  public let key: String
  public let name: String
  public let detailLines: [String]

  public init(key: String, name: String, detailLines: [String]) {
    self.key = key
    self.name = name
    self.detailLines = detailLines
  }
}

/// Which language blocks stay visible under the App Store–style "and N more" clamp.
///
/// Preferred languages (system + app) always stay open, English is kept as a base
/// even when it is not preferred, and a single leftover language is promoted rather
/// than hidden behind "and 1 more".
public enum LanguageListVisibility {

  public static func partition(_ groups: [MediaLanguageGroup],
                               preferredLanguages: [String],
                               alwaysIncludeEnglish: Bool = true)
  -> (visible: [MediaLanguageGroup], hiddenCount: Int) {
    guard !groups.isEmpty else { return ([], 0) }

    var keep = Set(preferredLanguages.map(SubtitleTracks.languageKey))
    if alwaysIncludeEnglish { keep.insert("en") }

    var visible = groups.filter { keep.contains($0.key) }
    var hidden = groups.filter { !keep.contains($0.key) }

    // Nothing matched preferred/English — still show at least the first language.
    if visible.isEmpty {
      visible = [groups[0]]
      hidden = Array(groups.dropFirst())
    }

    // A solitary leftover is cheaper to spell out than "and 1 more".
    if hidden.count == 1 {
      visible.append(contentsOf: hidden)
      hidden = []
    }

    return (visible, hidden.count)
  }
}
