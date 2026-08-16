//
//  FileInfo.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct FileInfo: Codable, Hashable {
  public let codec: String
  public let w: Int
  public let h: Int
  public let quality: String
  public let qualityID: Int
  public let url: URLInfo

  public init(codec: String, w: Int, h: Int, quality: String, qualityID: Int, url: URLInfo) {
    self.codec = codec
    self.w = w
    self.h = h
    self.quality = quality
    self.qualityID = qualityID
    self.url = url
  }

  private enum CodingKeys: String, CodingKey {
    case codec = "codec"
    case w = "w"
    case h = "h"
    case quality = "quality"
    case qualityID = "quality_id"
    case url = "url"
    case urls = "urls"
  }

  /// `/v1/items/<id>` names the link bag `url`; `/v1/items/media-links` names the same
  /// thing `urls`. One model either way — a file is a file, whichever call produced it.
  ///
  /// **A `nolinks=1` payload has neither.** It still lists the ladder — codec, quality,
  /// dimensions — with no links at all, and that is a legitimate file, not a malformed
  /// one: it describes what exists and says nothing about where. Requiring a link bag
  /// here failed the whole item (`item.seasons[0].episodes[0].files[0]`) and left the
  /// page on "Couldn't Load". `hasPlayableURL` is how callers tell the two apart.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    codec = (try? container.decode(String.self, forKey: .codec)) ?? ""
    w = (try? container.decode(Int.self, forKey: .w)) ?? 0
    h = (try? container.decode(Int.self, forKey: .h)) ?? 0
    quality = (try? container.decode(String.self, forKey: .quality)) ?? ""
    qualityID = (try? container.decode(Int.self, forKey: .qualityID)) ?? 0
    url = (try? container.decode(URLInfo.self, forKey: .url))
      ?? (try? container.decode(URLInfo.self, forKey: .urls))
      ?? URLInfo(http: "", hls: "", hls4: "", hls2: "")
  }

  /// Written back in the `/v1/items` shape — that is what `DownloadMeta` on disk holds.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(codec, forKey: .codec)
    try container.encode(w, forKey: .w)
    try container.encode(h, forKey: .h)
    try container.encode(quality, forKey: .quality)
    try container.encode(qualityID, forKey: .qualityID)
    try container.encode(url, forKey: .url)
  }
}

public extension FileInfo {
  var resolution: Int {
    Int(quality.dropLast()) ?? 0
  }

  /// False when this file came from a `nolinks=1` payload — the rung of the ladder is
  /// described but nothing is playable until `/v1/items/media-links` has been asked.
  var hasPlayableURL: Bool {
    !url.http.isEmpty || !url.hls4.isEmpty || !url.hls.isEmpty || !url.hls2.isEmpty
  }
}

public extension Array where Element == FileInfo {
  /// True when at least one rung of this ladder can actually be opened.
  var hasPlayableURLs: Bool {
    contains(where: \.hasPlayableURL)
  }

  /// One file per quality label. With the device profile's `mixedPlaylist` on, kino.pub
  /// returns both an HEVC and an h264 file for each resolution (same `quality`), which
  /// would otherwise show as duplicate rows in quality/download menus. Keeps the first
  /// per quality (HEVC, which kino.pub lists first) and preserves the original order.
  var dedupedByQuality: [FileInfo] {
    var seen = Set<String>()
    return filter { seen.insert($0.quality).inserted }
  }
}

extension FileInfo: Identifiable {
  public var id: Int {
    url.hashValue
  }
}
