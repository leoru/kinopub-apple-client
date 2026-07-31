//
//  CreateBookmarkFolderRequest.swift
//

import Foundation

/// Creates a bookmark folder — `POST /v1/bookmarks/create` with `title`. Response: `{folder:{id,…}}`.
public struct CreateBookmarkFolderRequest: Endpoint {

  public var title: String

  public init(title: String) {
    self.title = title
  }

  public var path: String { "/v1/bookmarks/create" }
  public var method: String { "POST" }
  public var parameters: [String: Any]? { ["title": title] }
  public var headers: [String: String]? { nil }
  // `title` is read from the form BODY only — as a query param the server returns
  // 400 "Title is too short" (verified live). Must be a body POST.
  public var forceSendAsGetParams: Bool { false }
}
