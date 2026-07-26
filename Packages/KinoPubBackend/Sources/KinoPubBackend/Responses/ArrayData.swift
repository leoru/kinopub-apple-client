//
//  ArrayData.swift
//
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation

public struct ArrayData<T: Codable>: Codable {

  public var items: [T]

  public init(items: [T]) {
    self.items = items
  }

  public static func mock(data: [T]) -> ArrayData {
    return ArrayData(items: data)
  }

  private enum CodingKeys: String, CodingKey {
    case items
    /// `/v1/bookmarks/get-item-folders` returns `folders` instead of `items`.
    case folders
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let items = try container.decodeIfPresent([T].self, forKey: .items) {
      self.items = items
    } else if let folders = try container.decodeIfPresent([T].self, forKey: .folders) {
      self.items = folders
    } else {
      throw DecodingError.keyNotFound(
        CodingKeys.items,
        DecodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Expected \"items\" or \"folders\" array"
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(items, forKey: .items)
  }

}
