//
//  Directory.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Directory: Codable, Hashable {
  public let id: Int
  public let title: String
  public let views: Int
  public let created: Int
  public let updated: Int

  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case title = "title"
    case views = "views"
    case created = "created"
    case updated = "updated"
  }

  public init(id: Int, title: String, views: Int, created: Int, updated: Int) {
    self.id = id
    self.title = title
    self.views = views
    self.created = created
    self.updated = updated
  }
}
