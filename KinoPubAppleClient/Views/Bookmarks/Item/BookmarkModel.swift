//
//  BookmarkModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging

@MainActor
class BookmarkModel: ObservableObject {

  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler

  public var bookmark: Bookmark
  @Published public var items: [MediaItem] = []
  @Published public private(set) var isLoading: Bool = false

  init(bookmark: Bookmark, itemsService: VideoContentService, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.bookmark = bookmark
    self.errorHandler = errorHandler
  }

  func fetchItems() async {
    isLoading = true
    defer { isLoading = false }
    do {
      items = try await contentService.fetchBookmarkItems(id: "\(bookmark.id)").items
    } catch {
      Logger.app.debug("fetch bookmark items error: \(error)")
      errorHandler.setError(error)
    }
  }

  @MainActor
  func refresh() {
    items = []
    Task {
      Logger.app.debug("refetch bookmark items")
      await fetchItems()
    }
  }

}
