//
//  ToggleWatchlistRequest.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct ToggleWatchlistRequest: Endpoint {

  public var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String {
    "/v1/watching/togglewatchlist"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    [
      "id": id
    ]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
