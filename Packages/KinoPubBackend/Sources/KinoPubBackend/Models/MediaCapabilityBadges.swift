//
//  MediaCapabilityBadges.swift
//  KinoPubBackend
//
//  Capability facts derived from item / file / optional HLS probes — not from the
//  local device's advertised decode support. Views decide how to render them.
//

import Foundation

/// Truthful playback/capability chips for a title. Decoupled from any specific UI
/// so posters, heroes and Info panels can share one source of facts.
public struct MediaCapabilityBadges: Hashable, Sendable {
  public var is4K: Bool
  public var isHD: Bool
  public var isHDR: Bool
  public var is3D: Bool
  public var ageRating: String?
  public var hasClosedCaptions: Bool
  public var languages: [String]
  public var audioChannelHint: String?

  public init(
    is4K: Bool = false,
    isHD: Bool = false,
    isHDR: Bool = false,
    is3D: Bool = false,
    ageRating: String? = nil,
    hasClosedCaptions: Bool = false,
    languages: [String] = [],
    audioChannelHint: String? = nil
  ) {
    self.is4K = is4K
    self.isHD = isHD
    self.isHDR = isHDR
    self.is3D = is3D
    self.ageRating = ageRating
    self.hasClosedCaptions = hasClosedCaptions
    self.languages = languages
    self.audioChannelHint = audioChannelHint
  }

  /// Compact chips suitable for a poster corner (defaults: 4K / HDR when known).
  public var posterChips: [String] {
    var chips: [String] = []
    if is4K { chips.append("4K") }
//    if isHDR { chips.append("HDR") }
    return chips
  }

  /// Richer set for detail / hero metadata.
  public var detailChips: [String] {
    var chips: [String] = []
      if is4K {
          chips.append("4K") }
//    } else if isHD {
//      chips.append("HD")
//    }
//    if isHDR { chips.append("HDR") }
  else  if is3D { chips.append("3D") }
    if let ageRating, !ageRating.isEmpty { chips.append(ageRating) }
//    if hasClosedCaptions { chips.append("CC") } // not that simple depends on lang etc better ignore it now
//    if let audioChannelHint, !audioChannelHint.isEmpty { chips.append(audioChannelHint) }
//    for language in languages.prefix(2) where !language.isEmpty {
//      chips.append(language)
//    }
    return chips
  }

  public var isEmpty: Bool {
    detailChips.isEmpty
  }

  /// Builds from the catalogue item. `videoRange` is the HLS `VIDEO-RANGE` when a
  /// playlist has been probed (`PQ` / `HLG` ⇒ HDR). Do not pass device capabilities.
  public static func from(
    item: MediaItem,
    ageRating: String? = nil,
    videoRange: String? = nil,
    closedCaptions: Bool? = nil
  ) -> MediaCapabilityBadges {
    let maxHeight = item.detailFiles.map(\.h).max() ?? 0
    let qualityHint = max(item.quality, maxHeight)
    let is4K = qualityHint >= 2160
    let isHD = !is4K && qualityHint >= 720
    let range = videoRange?.uppercased() ?? ""
    let isHDR = range == "PQ" || range == "HLG" || range.contains("HDR")
    let is3D = item.is3D
    let hasCC = closedCaptions ?? item.subtitles.contains { subtitle in
      let lang = subtitle.lang.lowercased()
      return lang.contains("cc") || lang.contains("sdh")
    }
    // Prefer a short surround cue from the AC-3 flag when channels aren't known yet.
    let audioHint: String? = (item.ac3 ?? 0) > 0 ? "DD" : nil
    return MediaCapabilityBadges(
      is4K: is4K,
      isHD: isHD,
//      isHDR: isHDR,
      is3D: is3D,
      ageRating: ageRating,
//      hasClosedCaptions: hasCC,
//      languages: [],
//      audioChannelHint: audioHint
    )
  }
}
