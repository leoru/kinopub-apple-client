//
//  ClearHistoryForMediaRequest.swift
//

import Foundation

/// Drops one video/episode from viewing history without clearing the whole title.
public struct ClearHistoryForMediaRequest: Endpoint {

  public var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String {
    "/v1/history/clear-for-media"
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
