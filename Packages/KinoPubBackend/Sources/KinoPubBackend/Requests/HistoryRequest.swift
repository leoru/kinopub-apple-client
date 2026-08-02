//
//  HistoryRequest.swift
//
//

import Foundation

/// Viewing history, newest first. Used to order the "continue watching" row by when
/// each title was last played.
public struct HistoryRequest: Endpoint {

  private var page: Int?
  private var perPage: Int

  public init(page: Int? = nil, perPage: Int = 20) {
    self.page = page
    self.perPage = perPage
  }

  public var path: String {
    "/v1/history"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    var params: [String: Any] = ["perpage": "\(perPage)"]
    if let page {
      params["page"] = "\(page)"
    }
    return params
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
