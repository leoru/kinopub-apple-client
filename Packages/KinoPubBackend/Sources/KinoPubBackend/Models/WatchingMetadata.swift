//
//  WatchingMetadata.swift
//
//
//  Created by Kirill Kunst on 13.11.2023.
//

import Foundation

public struct WatchingMetadata: Codable, Hashable {
  public let id: Int
  public let video: Int?
  public let season: Int?
  
  public init(id: Int, video: Int? = nil, season: Int? = nil) {
    self.id = id
    self.video = video
    self.season = season
  }
}
