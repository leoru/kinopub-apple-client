//
//  DownloadMeta.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 10.11.2023.
//

import Foundation
import KinoPubBackend

public struct DownloadMeta: PlayableItem, Codable, Equatable {
  public var id: Int
  public var files: [FileInfo]
  public var trailer: Trailer? { nil }
  public var originalTitle: String
  public var localizedTitle: String
  public var imageUrl: String
  public var metadata: WatchingMetadata
}

extension DownloadMeta {
  static func make(from item: DownloadableMediaItem) -> DownloadMeta {
    let originalTitle = item.mediaItem.isSeries ? "\(item.mediaItem.originalTitle) \(item.name)" : item.mediaItem.originalTitle
    let localizedTitle = item.mediaItem.isSeries ? "\(item.mediaItem.localizedTitle) \(item.name)" : item.mediaItem.localizedTitle
    return DownloadMeta(id: item.mediaItem.id,
                        files: item.files,
                        originalTitle: originalTitle,
                        localizedTitle: localizedTitle,
                        imageUrl: item.mediaItem.posters.small, metadata: item.watchingMetadata)
  }
}
