//
//  HLSManifest.swift
//  KinoPubAppleClient
//
//  Created by Sasha Romanov on 24.07.2026.
//

import Foundation

/// What an HLS master playlist actually advertises.
///
/// This is deliberately separate from what the API reports in `FileInfo.codec` and
/// `VideoAudio.codec`: those describe the *source* file, kino.pub transcodes on the way
/// out, and it is the delivered stream that decides whether AVFoundation can play it.
struct HLSManifest: Equatable {

  struct Variant: Equatable {
    var bandwidth: Int?
    var resolution: String?
    var codecs: [String]
    var frameRate: String?
    /// `SDR` / `PQ` / `HLG`. Absent on older playlists, which means SDR.
    var videoRange: String?
  }

  struct Rendition: Equatable {
    /// `AUDIO`, `SUBTITLES` or `CLOSED-CAPTIONS`.
    var type: String
    var name: String?
    var language: String?
    /// The `CHANNELS` attribute — "6" for 5.1, "2" for stereo. Optional in the spec, and
    /// kino.pub may well leave it out; that is itself worth knowing.
    var channels: String?
    var isDefault: Bool
    var forced: Bool
  }

  var variants: [Variant] = []
  var renditions: [Rendition] = []

  /// Every codec string across every variant, deduplicated.
  var allCodecs: [String] {
    Array(Set(variants.flatMap(\.codecs))).sorted()
  }
}

enum HLSManifestParser {

  static func parse(_ text: String) -> HLSManifest {
    var manifest = HLSManifest()

    for rawLine in text.split(whereSeparator: \.isNewline) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)

      if let list = line.dropping(prefix: "#EXT-X-STREAM-INF:") {
        let attributes = attributes(in: list)
        manifest.variants.append(
          HLSManifest.Variant(bandwidth: attributes["BANDWIDTH"].flatMap { Int($0) },
                              resolution: attributes["RESOLUTION"],
                              codecs: codecList(attributes["CODECS"]),
                              frameRate: attributes["FRAME-RATE"],
                              videoRange: attributes["VIDEO-RANGE"])
        )
      } else if let list = line.dropping(prefix: "#EXT-X-MEDIA:") {
        let attributes = attributes(in: list)
        manifest.renditions.append(
          HLSManifest.Rendition(type: attributes["TYPE"] ?? "UNKNOWN",
                                name: attributes["NAME"],
                                language: attributes["LANGUAGE"],
                                channels: attributes["CHANNELS"],
                                isDefault: attributes["DEFAULT"] == "YES",
                                forced: attributes["FORCED"] == "YES")
        )
      }
    }

    return manifest
  }

  private static func codecList(_ value: String?) -> [String] {
    (value ?? "")
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  /// Attribute lists are comma-separated, but a quoted value may itself contain commas —
  /// `CODECS="avc1.640028,mp4a.40.2"` is the usual offender, and splitting on every comma
  /// turns one codec list into two bogus attributes. Track the quotes instead.
  static func attributes(in list: String) -> [String: String] {
    var result: [String: String] = [:]
    var key = ""
    var value = ""
    var readingKey = true
    var inQuotes = false

    func commit() {
      let trimmedKey = key.trimmingCharacters(in: .whitespaces)
      if !trimmedKey.isEmpty {
        result[trimmedKey] = value.trimmingCharacters(in: .whitespaces)
      }
      key = ""
      value = ""
      readingKey = true
    }

    for character in list {
      switch character {
      case "\"":
        inQuotes.toggle()
      case "=" where readingKey && !inQuotes:
        readingKey = false
      case "," where !inQuotes:
        commit()
      default:
        if readingKey {
          key.append(character)
        } else {
          value.append(character)
        }
      }
    }
    commit()

    return result
  }
}

private extension String {
  /// `hasPrefix` + `dropFirst` in one step, so the prefix is only spelled once.
  func dropping(prefix: String) -> String? {
    hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
  }
}
