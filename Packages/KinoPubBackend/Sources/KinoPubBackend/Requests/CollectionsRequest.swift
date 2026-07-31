//
//  CollectionsRequest.swift
//

import Foundation

/// Lists curated collections — `GET /v1/collections`.
public struct CollectionsRequest: Endpoint {

  private var page: Int?
  private var perpage: Int?
  private var sort: String?

  public init(page: Int? = nil, perpage: Int? = nil, sort: String? = nil) {
    self.page = page
    self.perpage = perpage
    self.sort = sort
  }

  public var path: String { "/v1/collections" }
  public var method: String { "GET" }

  public var parameters: [String: Any]? {
    var params = [String: Any]()
    if let page { params["page"] = "\(page)" }
    if let perpage { params["perpage"] = "\(perpage)" }
    if let sort { params["sort"] = sort }
    return params
  }

  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { false }
}
