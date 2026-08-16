//
//  BookmarkModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubUI
import OSLog
import KinoPubLogging

@MainActor
class BookmarkModel: ObservableObject {

  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var isFetching = false

  public var bookmark: Bookmark
  @Published public var items: [MediaItem] = []
  @Published public private(set) var isLoading: Bool = false
  @Published public private(set) var paginationFailed: Bool = false
  /// A page past the first is in flight — the first page has its own loading state.
  @Published public private(set) var isLoadingMore: Bool = false

  /// What the grid footer should say.
  public var paginationState: PaginationState {
    if isLoadingMore { return PaginationState(phase: .loading, loadedCount: items.count) }
    if paginationFailed { return PaginationState(phase: .failed, loadedCount: items.count) }
    guard let pagination, pagination.current >= pagination.total else { return .idle }
    return PaginationState(phase: .complete, loadedCount: items.count)
  }
  @Published public private(set) var pagination: Pagination?

  init(bookmark: Bookmark, itemsService: VideoContentService, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.bookmark = bookmark
    self.errorHandler = errorHandler
  }

  func fetchItems() async {
    await fetchPage(reset: true)
  }

  func loadMoreContent(after item: MediaItem) {
    guard let pagination,
          CatalogLoadMore.isThresholdItem(item, in: items),
          pagination.current < pagination.total else {
      return
    }
    Task { await fetchPage(reset: false) }
  }

  func retryPagination() {
    paginationFailed = false
    Task { await fetchPage(reset: false) }
  }

  private func fetchPage(reset: Bool) async {
    let isFirstPage = reset || pagination == nil
    if !isFirstPage {
      guard !isFetching else { return }
    }
    isFetching = true
    defer { isFetching = false }
    // Only pages after the first: the first page owns the full-screen loading state.
    isLoadingMore = !isFirstPage
    defer { isLoadingMore = false }

    if isFirstPage { isLoading = true }
    defer { isLoading = false }

    do {
      let page = isFirstPage ? nil : pagination.map { $0.current + 1 }
      let data = try await contentService.fetchBookmarkItems(id: "\(bookmark.id)", page: page)
      if isFirstPage {
        items = data.items
      } else {
        items.append(contentsOf: data.items)
      }
      pagination = data.pagination
      paginationFailed = false
    } catch {
      Logger.app.debug("fetch bookmark items error: \(error)")
      if isFirstPage {
        errorHandler.setError(error)
      } else {
        paginationFailed = true
        errorHandler.setError(error)
      }
    }
  }

  @MainActor
  func refresh() {
    items = []
    pagination = nil
    paginationFailed = false
    Task {
      Logger.app.debug("refetch bookmark items")
      await fetchItems()
    }
  }

}
