//
//  DownloadableMediaItem.swift
//
//
//  Created by Kirill Kunst on 10.11.2023.
//

import Foundation

public struct DownloadableMediaItem: Hashable, Identifiable, Codable {
  public var name: String
  public var id: String { name }
  public var files: [FileInfo]
  public var mediaItem: MediaItem
  public var watchingMetadata: WatchingMetadata
  
  public init(name: String, files: [FileInfo], mediaItem: MediaItem, watchingMetadata: WatchingMetadata) {
    self.name = name
    self.files = files
    self.mediaItem = mediaItem
    self.watchingMetadata = watchingMetadata
  }
}
