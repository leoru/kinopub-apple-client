//
//  ClearHistoryForSeasonRequest.swift
//

import Foundation

/// Drops one season's watch history — `POST /v1/history/clear-for-season?id=<seasonId>`.
/// DESIGN: season-rail "clear progress" chrome TBD — service is ready via
/// `UserActionsService.clearHistoryForSeason`.
public struct ClearHistoryForSeasonRequest: Endpoint {

  public var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String {
    "/v1/history/clear-for-season"
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
