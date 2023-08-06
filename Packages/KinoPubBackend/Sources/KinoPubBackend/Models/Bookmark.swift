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
