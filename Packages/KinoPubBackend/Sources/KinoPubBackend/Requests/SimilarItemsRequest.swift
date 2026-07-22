//
//  SimilarItemsRequest.swift
//
//

import Foundation

/// The "more like this" list for a single item — `/v1/items/similar?id=<id>`. Returns
/// the same items envelope the catalog does, without pagination: the endpoint hands
/// back a fixed handful rather than a paged feed.
public struct SimilarItemsRequest: Endpoint {

  private let id: String

  public init(id: String) {
    self.id = id
  }

  public var path: String {
    "/v1/items/similar"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    ["id": id]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
