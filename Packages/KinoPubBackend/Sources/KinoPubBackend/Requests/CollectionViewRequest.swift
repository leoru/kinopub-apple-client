//
//  CollectionViewRequest.swift
//

import Foundation

/// Collection detail + items — `GET /v1/collections/view?id=`.
public struct CollectionViewRequest: Endpoint {

  private var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String { "/v1/collections/view" }
  public var method: String { "GET" }
  public var parameters: [String: Any]? { ["id": "\(id)"] }
  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { false }
}
