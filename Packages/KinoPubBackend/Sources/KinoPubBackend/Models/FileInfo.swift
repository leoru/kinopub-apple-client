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
  }
}

public extension FileInfo {
  var resolution: Int {
    Int(quality.dropLast()) ?? 0
  }
}

public extension Array where Element == FileInfo {
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
