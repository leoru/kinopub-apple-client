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
  
  /// False when the caller could not work out which **item** this is — an episode that
  /// was never stamped with its series id. Nothing may be reported to the server for
  /// one of these: the API answers 404 at best, and writes to the wrong title at worst.
  public var isResolved: Bool { id > 0 }

  public init(id: Int, video: Int? = nil, season: Int? = nil) {
    self.id = id
    self.video = video
    self.season = season
  }
}
