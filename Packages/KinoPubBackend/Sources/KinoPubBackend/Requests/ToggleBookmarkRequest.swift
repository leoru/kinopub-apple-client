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

  /// The server reads `item`/`folder` from the form BODY only — sent as query it returns
  /// 404 "item not found" and the toggle silently no-ops (verified live on community fork).
  public var forceSendAsGetParams: Bool { false }
}
