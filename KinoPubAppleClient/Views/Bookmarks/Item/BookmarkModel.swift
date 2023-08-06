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

  public var bookmark: Bookmark
  @Published public var items: [MediaItem] = MediaItem.skeletonMock()

  init(bookmark: Bookmark, itemsService: VideoContentService) {
    self.contentService = itemsService
    self.bookmark = bookmark
  }

  func fetchItems() async {
    do {
      items = try await contentService.fetchBookmarkItems(id: "\(bookmark.id)").items
    } catch {
      Logger.app.debug("fetch bookmark items error: \(error)")
    }
  }

  

  @MainActor
  func refresh() {
    items = MediaItem.skeletonMock()
    Task {
      Logger.app.debug("refetch bookmark items")
      await fetchItems()
    }
  }

}
