//
//  ToggleWatchingRequest.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct ToggleWatchingRequest: Endpoint {

  public var id: Int
  public var video: Int
  public var season: Int = -1
  
  init(id: Int, video: Int, season: Int? = nil) {
    self.id = id
    self.video = video
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
