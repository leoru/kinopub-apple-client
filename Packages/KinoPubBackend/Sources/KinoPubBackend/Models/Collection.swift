//
//  Collection.swift
//

import Foundation

/// A curated kino.pub collection (`GET /v1/collections`, `/v1/collections/view`).
public struct Collection: Decodable, Identifiable, Hashable {

  public struct Posters: Decodable, Hashable {
    public let small: String?
    public let medium: String?
    public let big: String?

    public init(small: String?, medium: String?, big: String?) {
      self.small = small
      self.medium = medium
      self.big = big
    }
  }

  public let id: Int
  public let title: String
  public let watchers: Int?
  public let views: Int?
  public let created: Int?
  public let updated: Int?
  public let itemsCount: Int?
  public let posters: Posters?

  private enum CodingKeys: String, CodingKey {
    case id
    case title
    case watchers
    case views
    case created
    case updated
    case itemsCount = "items_count"
    case posters
  }

  public init(
    id: Int,
    title: String,
    watchers: Int? = nil,
    views: Int? = nil,
    created: Int? = nil,
    updated: Int? = nil,
    itemsCount: Int? = nil,
    posters: Posters? = nil
  ) {
    self.id = id
    self.title = title
    self.watchers = watchers
    self.views = views
    self.created = created
    self.updated = updated
    self.itemsCount = itemsCount
    self.posters = posters
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(Int.self, forKey: .id)
    self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    self.watchers = try container.decodeIfPresent(Int.self, forKey: .watchers)
    self.views = try container.decodeIfPresent(Int.self, forKey: .views)
    self.created = try container.decodeIfPresent(Int.self, forKey: .created)
    self.updated = try container.decodeIfPresent(Int.self, forKey: .updated)
    self.itemsCount = try container.decodeIfPresent(Int.self, forKey: .itemsCount)
    self.posters = try container.decodeIfPresent(Posters.self, forKey: .posters)
  }

  public static func mock(
    id: Int = 0,
    title: String = "Collection",
    posters: Posters? = nil
  ) -> Collection {
    Collection(id: id, title: title, posters: posters)
  }
}
