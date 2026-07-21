//
//  WatchingMoviesRequest.swift
//
//

import Foundation

/// Movies, concerts and documentaries the user started but never finished.
public struct WatchingMoviesRequest: Endpoint {

  public init() { }

  public var path: String {
    "/v1/watching/movies"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    nil
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
