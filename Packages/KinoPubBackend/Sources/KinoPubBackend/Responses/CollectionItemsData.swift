//
//  CollectionItemsData.swift
//

import Foundation

public struct CollectionItemsData: Decodable {

  public let collection: Collection?
  public let items: [MediaItem]

  private enum CodingKeys: String, CodingKey {
    case collection
    case items
  }

  public init(collection: Collection?, items: [MediaItem]) {
    self.collection = collection
    self.items = items
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.collection = try container.decodeIfPresent(Collection.self, forKey: .collection)
    // A single bad MediaItem must not blank the whole collection.
    self.items = container.decodeLossyArray(MediaItem.self, forKey: .items)
  }

  public static func mock(collection: Collection? = nil, items: [MediaItem] = []) -> CollectionItemsData {
    CollectionItemsData(collection: collection, items: items)
  }
}
