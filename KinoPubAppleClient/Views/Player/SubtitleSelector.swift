//
//  SubtitleSelector.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

enum SubtitleSelector {
  private static let englishLangs: Set<String> = ["eng", "en", "en-us", "en-gb", "en-uk"]
  private static let ccMarkers = ["cc", "sdh", "hi", "forced", "caption"]

  static func preferred(from subtitles: [Subtitle], preferNonCC: Bool) -> Subtitle? {
    let english = subtitles.filter { isEnglish($0.lang) }
    guard !english.isEmpty else { return nil }

    let ranked: [Subtitle]
    if preferNonCC {
      let nonCC = english.filter { !looksLikeCC($0) }
      ranked = nonCC.isEmpty ? english : nonCC
    } else {
      ranked = english
    }

    // Prefer tracks with a fetchable sidecar URL for cue parsing / word translation.
    if let withURL = ranked.first(where: { !$0.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
      return withURL
    }
    return ranked.first
  }

  static func isEnglish(_ lang: String) -> Bool {
    englishLangs.contains(lang.lowercased())
  }

  static func looksLikeCC(_ subtitle: Subtitle) -> Bool {
    let haystack = (subtitle.url + " " + subtitle.lang).lowercased()
    return ccMarkers.contains { marker in
      haystack.range(of: #"\b\#(marker)\b"#, options: .regularExpression) != nil
        || haystack.contains(".\(marker).")
        || haystack.contains("_\(marker)_")
        || haystack.contains("-\(marker)-")
        || haystack.contains("/\(marker)/")
        || haystack.hasSuffix(".\(marker)")
    }
  }

  static func looksLikeCCDisplayName(_ name: String) -> Bool {
    let lower = name.lowercased()
    return ccMarkers.contains { lower.contains($0) }
  }
}
