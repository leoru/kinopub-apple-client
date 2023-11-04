//
//  Season.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Season: Codable, Hashable {
  public let title: String
  public let number: Int
  public let watching: SeasonWatching
  public let episodes: [Episode]
  
  private enum CodingKeys: String, CodingKey {
    case title = "title"
    case number = "number"
    case watching = "watching"
    case episodes = "episodes"
  }
  
  public var fixedTitle: String {
    if title.isEmpty {
      return "Сезон \(number)"
    }
    return title
  }
}

extension Season: Identifiable {
  public var id: String {
    "\(number)"
  }
}
