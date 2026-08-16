//
//  MediaCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// How many items the full-screen catalog grids (Movies / Series tabs and the pushed
/// "see all" pages) request per page. Roomy screens show many rows at once, so a
/// 20-item page paginates visibly as you scroll; 50 keeps it seamless. iPhone stays at
/// 20 to keep payloads light. Home rails and the background `StreamSurvey` keep the
/// server default — they call the terse `fetch`/`search` overloads, not this.
@MainActor
enum CatalogPageSize {
  static var grid: Int {
#if os(macOS) || os(tvOS)
    50
#else
    UIDevice.current.userInterfaceIdiom == .pad ? 50 : 20
#endif
  }
}

@MainActor
class MediaCatalog: ObservableObject {

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  /// Page size for these grids: 50 on roomy screens (Mac / tvOS / iPad), 20 on iPhone,
  /// so a screenful doesn't paginate visibly. Fixed at birth — the idiom can't change
  /// under a live view. See `CatalogPageSize`.
  private let perPage: Int
  private var bag = Set<AnyCancellable>()
  private var isFetching = false

  @Published public var items: [MediaItem] = []
  /// Drives the spinner: only true while the first page is on its way, so paging
  /// further down never blanks the grid.
  @Published public private(set) var isLoading: Bool = false
  /// True when the first page failed — the grid has nothing to show, so the view
  /// swaps to a retry state.
  @Published public private(set) var loadFailed: Bool = false
  /// The failure behind `loadFailed`, so the retry state can say what actually went wrong.
  @Published public private(set) var loadError: Error?
  /// True when a page past the first failed — loaded items stay on screen and the
  /// grid offers an inline retry at the bottom instead of swapping to an error screen.
  @Published public private(set) var paginationFailed: Bool = false
  @Published public var pagination: Pagination?
  @Published public var contentType: MediaType = .movie
  @Published public var shortcut: MediaShortcut = .hot
  @Published public var query: String = ""

  var title: String {
    contentType.title
  }

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       contentType: MediaType = .movie,
       shortcut: MediaShortcut = .hot) {
    self.itemsService = itemsService
    self.perPage = CatalogPageSize.grid
    self.authState = authState
    self.errorHandler = errorHandler
    self.contentType = contentType
    // Assigned before `subscribe()` so the `$shortcut.dropFirst()` sink doesn't fire a
    // spurious refresh when a catalog is pinned to a non-default shortcut at birth.
    self.shortcut = shortcut
    subscribe()
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    let isFirstPage = pagination == nil
    // Pagination triggers fire per visible cell — drop duplicates while a page is
    // already on its way. First-page loads (refresh, shortcut change) always run.
    if !isFirstPage {
      guard !isFetching else { return }
    }
    isFetching = true
    defer { isFetching = false }

    if isFirstPage { isLoading = true }
    defer { isLoading = false }

    do {
      let page = isFirstPage ? nil : pagination!.current + 1
      if !query.isEmpty {
        let data = try await itemsService.search(query: query, page: page, perPage: perPage)
        handleData(data, isFirstPage: isFirstPage)
      } else {
        let data = try await itemsService.fetch(shortcut: shortcut, contentType: contentType, page: page, perPage: perPage)
        handleData(data, isFirstPage: isFirstPage)
      }
      loadFailed = false
      loadError = nil
      paginationFailed = false
    } catch {
      if isFirstPage {
        loadFailed = true
        loadError = error
        Logger.app.error("Catalog first page fetch failed: \(error)")
      } else {
        paginationFailed = true
        Logger.app.debug("Catalog page fetch failed, keeping loaded items: \(error)")
        errorHandler.setError(error)
      }
    }
  }

  /// Retries the page that failed — the grid and its scroll position stay as they are.
  func retryPagination() {
    paginationFailed = false
    Task { await fetchItems() }
  }

  private func handleData(_ data: PaginatedData<MediaItem>, isFirstPage: Bool) {
    if isFirstPage {
      items = data.items
    } else {
      items.append(contentsOf: data.items)
    }
    pagination = data.pagination
  }

  func loadMoreContent(after item: MediaItem) {
    guard let pagination = pagination else {
      return
    }

    // O(1) by id — never firstIndex(of:), which deep-compares MediaItem.
    guard CatalogLoadMore.isThresholdItem(item, in: items),
          pagination.current <= pagination.total else {
      return
    }
    Logger.app.debug("load more content after item: \(item.id)")
    Task {
      await fetchItems()
    }
  }

  @MainActor
  func refresh() {
    items = []
    pagination = nil
    loadFailed = false
    loadError = nil
    paginationFailed = false
    errorHandler.reset()
    Task {
      Logger.app.debug("refetch items")
      await fetchItems()
    }
  }

  private func subscribe() {
    $contentType
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] _ in
      self?.refresh()
    }.store(in: &bag)

    $shortcut
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] _ in
      self?.refresh()
    }.store(in: &bag)

    $query
      .dropFirst()
      .removeDuplicates()
      .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
      self?.refresh()
    }.store(in: &bag)
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized })
      .first()
      .removeDuplicates()
      .sink { [weak self] _ in
      self?.refresh()
    }.store(in: &bag)
  }

}
