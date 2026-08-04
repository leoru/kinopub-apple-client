//
//  BookmarkItemsRequest.swift
//

import Foundation

public struct BookmarkItemsRequest: Endpoint {

  private var id: String
  private var page: Int?

  public init(id: String, page: Int? = nil) {
    self.id = id
    self.page = page
  }

  public var path: String {
    "/v1/bookmarks/\(id)"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    guard let page else { return nil }
    return ["page": "\(page)"]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
