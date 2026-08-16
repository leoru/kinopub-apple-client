//
//  ItemDetailsRequest.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation

public struct ItemDetailsRequest: Endpoint {

  private var id: String
  private var excludeLinks: Bool

  /// - Parameter excludeLinks: sends `nolinks=1`. On a series the video links are the
  ///   bulk of the response and all but the episode actually played are wasted; ask for
  ///   them per media with `MediaLinksRequest` instead. kino.pub is making `1` the
  ///   default in a future version and dropping the parameter after that.
  public init(id: String, excludeLinks: Bool = false) {
    self.id = id
    self.excludeLinks = excludeLinks
  }

  public var path: String {
    "/v1/items/\(id)"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    excludeLinks ? ["nolinks": 1] : nil
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { excludeLinks }
}
