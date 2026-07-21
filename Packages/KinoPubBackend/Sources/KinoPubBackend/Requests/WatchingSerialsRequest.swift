//
//  WatchingSerialsRequest.swift
//
//

import Foundation

/// Serials with unwatched episodes.
public struct WatchingSerialsRequest: Endpoint {

  /// `false` returns everything unwatched, `true` limits it to the user's watchlist.
  private var subscribedOnly: Bool

  public init(subscribedOnly: Bool = false) {
    self.subscribedOnly = subscribedOnly
  }

  public var path: String {
    "/v1/watching/serials"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    ["subscribed": subscribedOnly ? "1" : "0"]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
