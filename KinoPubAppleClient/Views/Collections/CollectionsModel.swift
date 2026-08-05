//
//  CollectionsModel.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import KinoPubUI
import OSLog
import KinoPubLogging
import Combine

/// The full collections browser: one shelf per curated collection, each shelf
/// a preview of that collection's own items. `/v1/collections` returns only the
/// collection metadata — the preview cards come from a per-collection fetch
/// (`/v1/collections/view`), run in parallel and capped, same tradeoff the
/// community fork made for the same endpoint shape.
@MainActor
class CollectionsModel: ObservableObject {

  /// Cards shown per shelf before the row defers the rest to the collection's
  /// own detail page.
  static let previewCardCount = 12

  @Published public private(set) var rows: [MediaRow] = []
  @Published public private(set) var isLoaded: Bool = false
  @Published public private(set) var loadFailed: Bool = false
  @Published public private(set) var loadError: Error?

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var collectionsService: CollectionsService
  private var pagination: Pagination?
  private var isFetchingMore = false
  private var bag = Set<AnyCancellable>()

  init(collectionsService: CollectionsService,
       authState: AuthState,
       errorHandler: ErrorHandler) {
    self.collectionsService = collectionsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  func fetch() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }
    guard !isLoaded else { return }
    await loadFirstPage()
  }

  func refresh() async {
    errorHandler.reset()
    isLoaded = false
    pagination = nil
    rows = []
    await loadFirstPage()
  }

  /// Fires from `MediaRowsView.onRowAppear` — pages in more collections once the
  /// last loaded shelf is on screen.
  func loadMoreIfNeeded(after row: MediaRow) {
    guard row.id == rows.last?.id,
          let pagination, pagination.current < pagination.total,
          !isFetchingMore else { return }
    Task { await fetchNextPage() }
  }

  private func loadFirstPage() async {
    do {
      let data = try await collectionsService.fetchCollections(page: nil, sort: nil)
      pagination = data.pagination
      rows = await Self.rows(for: data.collections, service: collectionsService)
      loadFailed = false
      loadError = nil
    } catch {
      Logger.app.debug("fetch collections error: \(error)")
      loadFailed = true
      loadError = error
    }
    isLoaded = true
  }

  private func fetchNextPage() async {
    guard let pagination, !isFetchingMore else { return }
    isFetchingMore = true
    defer { isFetchingMore = false }
    do {
      let data = try await collectionsService.fetchCollections(page: pagination.current + 1, sort: nil)
      self.pagination = data.pagination
      rows.append(contentsOf: await Self.rows(for: data.collections, service: collectionsService))
    } catch {
      Logger.app.debug("fetch more collections error: \(error)")
      errorHandler.setError(error)
    }
  }

  /// One row per collection, in the order the API returned them. A collection
  /// whose preview fetch fails or comes back empty is dropped rather than shown
  /// as a dead shelf.
  private static func rows(for collections: [Collection], service: CollectionsService) async -> [MediaRow] {
    await withTaskGroup(of: (Int, MediaRow?).self) { group in
      for (index, collection) in collections.enumerated() {
        group.addTask {
          let items = (try? await service.fetchCollection(id: collection.id).1) ?? []
          guard !items.isEmpty else { return (index, nil) }
          let cards = items.prefix(previewCardCount).map { MediaCard($0) }
          let row = MediaRow(id: "collection-\(collection.id)",
                             title: collection.title,
                             count: collection.itemsCount.map { String($0) },
                             cards: Array(cards),
                             destination: Route.collection(collection))
          return (index, row)
        }
      }
      var slots = [MediaRow?](repeating: nil, count: collections.count)
      for await (index, row) in group {
        slots[index] = row
      }
      return slots.compactMap { $0 }
    }
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized })
      .first()
      .removeDuplicates()
      .sink { [weak self] _ in
        Task { await self?.fetch() }
      }.store(in: &bag)
  }
}
