//
//  ToggleBookmarkRequest.swift
//
//

import Foundation

/// Adds the item to a folder, or removes it if it is already there.
public struct ToggleBookmarkRequest: Endpoint {

  private var itemId: Int
  private var folderId: Int

  public init(itemId: Int, folderId: Int) {
    self.itemId = itemId
    self.folderId = folderId
  }

  public var path: String {
    "/v1/bookmarks/toggle-item"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    ["item": itemId, "folder": folderId]
  }

  public var headers: [String: String]? {
    nil
  }

  /// The service reads these from the query string even on POST, as it does for the
  /// other action endpoints.
  public var forceSendAsGetParams: Bool { true }
}
