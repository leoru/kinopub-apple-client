//
//  BookmarkFolderItemsData.swift
//

import Foundation

/// Folder contents from `GET /v1/bookmarks/<id>`. Pagination is optional — the
/// live API sometimes returns the full folder in one shot and sometimes pages.
public struct BookmarkFolderItemsData: Codable {
  public var items: [MediaItem]
  public var pagination: Pagination?

  public init(items: [MediaItem], pagination: Pagination? = nil) {
    self.items = items
    self.pagination = pagination
  }
}
