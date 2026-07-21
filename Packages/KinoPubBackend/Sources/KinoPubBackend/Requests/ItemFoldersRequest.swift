//
//  ItemFoldersRequest.swift
//
//

import Foundation

/// Which bookmark folders already contain an item.
public struct ItemFoldersRequest: Endpoint {

  private var itemId: Int

  public init(itemId: Int) {
    self.itemId = itemId
  }

  public var path: String {
    "/v1/bookmarks/get-item-folders"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    ["item": itemId]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { true }
}
