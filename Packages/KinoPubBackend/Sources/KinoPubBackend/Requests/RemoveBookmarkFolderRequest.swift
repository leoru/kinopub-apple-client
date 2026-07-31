//
//  RemoveBookmarkFolderRequest.swift
//

import Foundation

/// Deletes a bookmark folder — `POST /v1/bookmarks/remove-folder` with `folder`.
public struct RemoveBookmarkFolderRequest: Endpoint {

  public var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String {
    "/v1/bookmarks/remove-folder"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    ["folder": id]
  }

  public var headers: [String: String]? {
    nil
  }

  // `folder` is read from the form BODY only (verified live: body → 200, query → no-op).
  public var forceSendAsGetParams: Bool { false }
}
