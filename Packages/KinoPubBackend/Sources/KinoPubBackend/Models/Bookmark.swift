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
  public var skeleton: Bool?

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case views
    case count
    case created
    case updated
    case skeleton
  }

  public init(id: Int,
              title: String,
              views: Int,
              count: String,
              created: Int,
              updated: Int,
              skeleton: Bool? = nil) {
    self.id = id
    self.title = title
    self.views = views
    self.count = count
    self.created = created
    self.updated = updated
    self.skeleton = skeleton
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try container.decode(Int.self, forKey: .id)
    title = try container.decode(String.self, forKey: .title)
    views = try container.decode(Int.self, forKey: .views)
    created = try container.decode(Int.self, forKey: .created)
    updated = try container.decode(Int.self, forKey: .updated)
    skeleton = try container.decodeIfPresent(Bool.self, forKey: .skeleton)

    if let numericCount = try? container.decode(Int.self, forKey: .count) {
      count = String(numericCount)
    } else if let stringCount = try? container.decode(String.self, forKey: .count) {
      count = stringCount
    } else {
      throw DecodingError.typeMismatch(
        String.self,
        DecodingError.Context(
          codingPath: container.codingPath + [CodingKeys.count],
          debugDescription: "Expected bookmark count to be a string or integer."
        )
      )
    }
  }
}

public extension Bookmark {
  static func skeletonMock() -> [Bookmark] {
    (0..<4).map { id in
      mock(id: id, skeleton: true)
    }
  }

  static func mock(id: Int = 1, skeleton: Bool = false) -> Bookmark {
    Bookmark(id: id, title: "", views: 0, count: "", created: 0, updated: 0, skeleton: skeleton)
  }
}

extension Bookmark: Identifiable { }
extension Bookmark: Hashable { }
