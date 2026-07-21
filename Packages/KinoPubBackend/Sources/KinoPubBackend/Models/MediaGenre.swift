//
//  MediaGenre.swift
//  
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation

public struct MediaGenre: Codable, Hashable, Identifiable {
  /// Int, not String: the API sends `"id": 25`, so the old `String` declaration made
  /// every genre response fail to decode.
  public let id: Int
  public let title: String
  public let type: MediaType?

  public init(id: Int, title: String, type: MediaType? = nil) {
    self.id = id
    self.title = title
    self.type = type
  }
}
