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

/// The full collections browser: a paginated grid of curated collection covers
/// (`GET /v1/collections`). Each cover opens that collection's item grid — no
/// per-collection preview fetch (covers already ship on the list endpoint).
@MainActor
class CollectionsModel: ObservableObject {

  @Published public private(set) var cards: [MediaCard] = []
  @Published public private(set) var isLoaded: Bool = false
  @Published public private(set) var loadFailed: Bool = false
  @Published public private(set) var loadError: Error?
  @Published public private(set) var paginationError: Bool = false

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
    cards = []
    paginationError = false
    await loadFirstPage()
  }

  /// Fires from `MediaCardsListView.onLoadMoreContent` — pages in more covers
  /// once the last loaded card is on screen.
  func loadMoreIfNeeded(after card: MediaCard) {
    guard card.id == cards.last?.id,
          let pagination, pagination.current < pagination.total,
          !isFetchingMore else { return }
    Task { await fetchNextPage() }
  }

  func retryPagination() {
    guard !isFetchingMore else { return }
    Task { await fetchNextPage() }
  }

  private func loadFirstPage() async {
    do {
      let data = try await collectionsService.fetchCollections(page: nil, sort: nil)
      pagination = data.pagination
      cards = data.collections.map(CollectionMediaCard.make(from:))
      loadFailed = false
      loadError = nil
      paginationError = false
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
      cards.append(contentsOf: data.collections.map(CollectionMediaCard.make(from:)))
      paginationError = false
    } catch {
      Logger.app.debug("fetch more collections error: \(error)")
      paginationError = true
      errorHandler.setError(error)
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

/// Shared mapping from curated `Collection` metadata → poster `MediaCard` used by
/// Home's preview row and the full Collections grid.
enum CollectionMediaCard {

  static func make(from collection: Collection) -> MediaCard {
    MediaCard(
      id: collection.id,
      posterURL: collection.posters?.medium
        ?? collection.posters?.big
        ?? collection.posters?.small
        ?? "",
      title: collection.title,
      subtitle: updatedSubtitle(from: collection.updated),
      opensCollection: true,
      captionStats: captionStats(for: collection)
    )
  }

  /// Route payload for a collection cover — id + title are enough for detail; the
  /// screen refetches `/v1/collections/view` for the full item list.
  static func routeCollection(from card: MediaCard) -> Collection {
    Collection(
      id: card.id,
      title: card.title,
      posters: Collection.Posters(small: card.posterURL, medium: card.posterURL, big: card.posterURL)
    )
  }

  private static func captionStats(for collection: Collection) -> [MediaCardCaptionStat] {
    var stats: [MediaCardCaptionStat] = []
    if let watchers = collection.watchers, watchers > 0 {
      stats.append(MediaCardCaptionStat(systemImage: "person.2", value: compact(watchers)))
    }
    if let views = collection.views, views > 0 {
      stats.append(MediaCardCaptionStat(systemImage: "eye", value: compact(views)))
    }
    return stats
  }

  private static func updatedSubtitle(from timestamp: Int?) -> String? {
    guard let timestamp, timestamp > 0 else { return nil }
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    return date.formatted(date: .abbreviated, time: .omitted)
  }

  /// Compact count, e.g. 12_345 → "12K".
  private static func compact(_ value: Int) -> String {
    value.formatted(.number.notation(.compactName))
  }
}
