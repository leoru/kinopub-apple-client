//
//  Season.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class Season: Codable, Hashable, Identifiable {
  public static func == (lhs: Season, rhs: Season) -> Bool {
    lhs.id == rhs.id
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
  
  public let id: Int
  public let title: String
  public let number: Int
  public let watching: SeasonWatching
  public let episodes: [Episode]
  public var mediaId: Int? = nil
  
  public init(id: Int,
       title: String,
       number: Int,
       watching: SeasonWatching,
       episodes: [Episode]) {
    self.id = id
    self.title = title
    self.number = number
    self.watching = watching
    self.episodes = episodes
  }
  
  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case title = "title"
    case number = "number"
    case watching = "watching"
    case episodes = "episodes"
    case mediaId = "mediaId"
  }
  
  public var fixedTitle: String {
    if title.isEmpty {
      return "Сезон \(number)"
    }
    return title
  }
  
  
}
