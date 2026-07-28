//
//  Bookmark.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Bookmark: Codable {
  public let id: Int
  public let title: String
  public let views: Int
  public let count: String
  public let created: Int
  public let updated: Int

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case views
    case count
    case created
    case updated
  }

  public init(id: Int,
              title: String,
              views: Int,
              count: String,
              created: Int,
              updated: Int) {
    self.id = id
    self.title = title
    self.views = views
    self.count = count
    self.created = created
    self.updated = updated
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(Int.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    views = try container.decode(Int.self, forKey: .views)
    created = try container.decode(Int.self, forKey: .created)
    updated = try container.decode(Int.self, forKey: .updated)

    if let numericCount = try? container.decode(Int.self, forKey: .count) {
      count = String(numericCount)
    } else if let stringCount = try? container.decode(String.self, forKey: .count) {
      count = stringCount
    } else {
      // `/v1/bookmarks/get-item-folders` returns folders with no `count` at all; a
      // missing or unreadable count means "nothing to show", not a failed screen.
      count = ""
    }
  }
}

public extension Array where Element == Bookmark {
  /// Folders in the order Saved shows them: whichever gained an item most recently comes
  /// first, so a list added to last week outranks one last touched two months ago.
  /// `updated` moves with the folder's contents — items themselves carry no "added"
  /// date, so it is the only signal the API gives for this.
  func recentlyUpdatedFirst() -> [Bookmark] {
    sorted { ($0.updated, $0.created, $0.id) > ($1.updated, $1.created, $1.id) }
  }
}

public extension Bookmark {
  static func mock(id: Int = 1) -> Bookmark {
    Bookmark(id: id, title: "", views: 0, count: "", created: 0, updated: 0)
  }
}

extension Bookmark: Identifiable { }
extension Bookmark: Hashable { }
