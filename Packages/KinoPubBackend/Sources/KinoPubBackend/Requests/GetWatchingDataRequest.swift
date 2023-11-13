//
//  GetWatchingDataRequest.swift
//  
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct GetWatchingDataRequest: Endpoint {
  
  public var id: Int
  public var video: Int = -1
  public var season: Int = -1
  
  init(id: Int, time: Int, video: Int? = nil, season: Int? = nil) {
    self.id = id
    self.video = video ?? -1
    self.season = season ?? -1
  }
  
  
  public var path: String {
    "/v1/watching"
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
