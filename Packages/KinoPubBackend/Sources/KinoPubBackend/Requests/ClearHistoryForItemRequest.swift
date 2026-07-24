//
//  ClearHistoryForItemRequest.swift
//

import Foundation

/// Drops a title from viewing history — and therefore from Continue Watching.
public struct ClearHistoryForItemRequest: Endpoint {

  public var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String {
    "/v1/history/clear-for-item"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    ["id": id]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
