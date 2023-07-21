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
}

extension Bookmark: Identifiable { }
extension Bookmark: Hashable { }
