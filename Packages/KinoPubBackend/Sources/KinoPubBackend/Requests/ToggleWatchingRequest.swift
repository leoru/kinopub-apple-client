//
//  ToggleWatchingRequest.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct ToggleWatchingRequest: Endpoint {

  public var id: Int
  public var video: Int = -1
  public var season: Int = -1

  /// - Parameters:
  ///   - video: Episode/video number. Omit to toggle every episode in `season`.
  ///   - season: Series only. Omit for films.
  public init(id: Int, video: Int? = nil, season: Int? = nil) {
    self.id = id
    self.video = video ?? -1
    self.season = season ?? -1
  }

  public var path: String {
    "/v1/watching/toggle"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    [
      "id": id,
      "video": video,
      "season": season
    ].filter({ $0.value != -1 })
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
