//
//  LibrarySectionCatalog.swift
//  KinoPubAppleClient
//

import Foundation
import Combine
import KinoPubBackend
import KinoPubUI
import KinoPubLogging
import OSLog

/// The grid behind one Library sidebar section.
///
/// Page 1 lives in `ContentStore`, so switching back to a section paints instantly
/// (and still paints offline). Pages past the first are session-only: `RowState` has
/// no pagination, and caching a half-scrolled folder to disk would mean deciding what
/// a partially-cached list even means on the next launch. Scroll position is not
/// restored across section switches either, so the extra pages have nothing to serve.
@MainActor
final class LibrarySectionCatalog: ObservableObject {

  /// Page 1 (from the store) followed by any pages this session has paged in.
  @Published private(set) var cards: [MediaCard] = []
  /// True while the first page is on its way — the grid draws placeholders.
  @Published private(set) var isLoading = false
  @Published private(set) var isLoaded = false
  /// Nothing to show *and* the fetch failed — the view swaps to a retry state. A
  /// cached page always wins over this.
  @Published private(set) var loadFailed = false
  @Published private(set) var loadError: Error?
  /// A page past the first failed: keep what is on screen, offer an inline retry.
  @Published private(set) var paginationFailed = false

  private(set) var section: LibrarySection = .watchlist

  private var pagedCards: [MediaCard] = []
  private var pagination: Pagination?
  private var isFetchingPage = false

  private let contentService: VideoContentService
  private let authState: AuthState
  private let errorHandler: ErrorHandler
  private let store: ContentStore
  private var bag = Set<AnyCancellable>()

  init(contentService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       store: ContentStore = AppContext.shared.contentStore) {
    self.contentService = contentService
    self.authState = authState
    self.errorHandler = errorHandler
    self.store = store
  }

  // MARK: - Section switching

  /// Point the catalog at a section: paint whatever is cached for it, then refresh in
  /// the background if that cache is stale. Safe to call again for the same section.
  func activate(_ section: LibrarySection) async {
    if section != self.section {
      self.section = section
      pagedCards = []
      pagination = nil
      paginationFailed = false
      loadFailed = false
      loadError = nil
      isLoaded = false
    }
    await load(force: false)
  }

  @Sendable
  func refresh() async {
    errorHandler.reset()
    pagedCards = []
    pagination = nil
    paginationFailed = false
    await load(force: true)
  }

  private func load(force: Bool) async {
    guard section.usesCardGrid else {
      cards = []
      isLoaded = true
      return
    }
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }
    guard let key = section.rowKey else { return }

    // Paint first, fetch second — even a stale page beats an empty pane.
    publishCards()
    isLoading = cards.isEmpty
    isLoaded = !cards.isEmpty

    let section = self.section
    let service = contentService
    let fetch: @Sendable () async throws -> [MediaCard] = {
      try await Self.firstPage(of: section, using: service).cards
    }
    if force {
      await store.refresh(key, fetch: fetch)
    } else {
      await store.refreshIfStale(key, fetch: fetch)
    }
    // A slow switch can resolve after the user has moved on — don't paint someone
    // else's section over the current one.
    guard section == self.section else { return }

    publishCards()
    isLoading = false
    isLoaded = true
    let error = store.lastError(key)
    loadFailed = cards.isEmpty && error != nil
    loadError = cards.isEmpty ? error : nil
    if !cards.isEmpty, let error {
      errorHandler.setError(error)
    }
  }

  private func publishCards() {
    let cached = section.rowKey.map { store.cards($0) } ?? []
    cards = cached + pagedCards
  }

  // MARK: - Pagination

  func loadMoreContent(after card: MediaCard) {
    guard section.isPaginated,
          CatalogLoadMore.isThresholdID(card.id, lastID: cards.last?.id),
          !isFetchingPage else { return }
    if let pagination, pagination.current >= pagination.total { return }
    // Page 1 came from the store, which keeps no pagination — ask for page 2 and let
    // the response tell us whether there is more after that.
    let next = pagination.map { $0.current + 1 } ?? 2
    Task { await loadPage(next) }
  }

  func retryPagination() {
    paginationFailed = false
    let next = pagination.map { $0.current + 1 } ?? 2
    Task { await loadPage(next) }
  }

  private func loadPage(_ page: Int) async {
    guard !isFetchingPage else { return }
    isFetchingPage = true
    defer { isFetchingPage = false }

    let section = self.section
    do {
      let result = try await Self.page(page, of: section, using: contentService)
      guard section == self.section else { return }
      pagedCards.append(contentsOf: result.cards)
      pagination = result.pagination
      paginationFailed = false
      publishCards()
    } catch {
      guard section == self.section else { return }
      paginationFailed = true
      Logger.app.debug("Library section page \(page) failed, keeping loaded cards: \(error)")
      errorHandler.setError(error)
    }
  }

  // MARK: - Fetching

  private struct PageResult {
    var cards: [MediaCard]
    var pagination: Pagination?
  }

  private nonisolated static func firstPage(of section: LibrarySection,
                                            using service: VideoContentService) async throws -> PageResult {
    try await page(nil, of: section, using: service)
  }

  private nonisolated static func page(_ page: Int?,
                                       of section: LibrarySection,
                                       using service: VideoContentService) async throws -> PageResult {
    switch section {
    case .watchlist:
      let items = try await service.fetchWatchingSerials(subscribedOnly: true).items
      return PageResult(cards: items.map { card(for: $0, isSeries: true) }, pagination: nil)
    case .movies:
      let items = try await service.fetchWatchingMovies().items
      return PageResult(cards: items.map { card(for: $0, isSeries: false) }, pagination: nil)
    case .history:
      let data = try await service.fetchHistory(page: page)
      return PageResult(cards: HistoryView.cards(from: data.history), pagination: data.pagination)
    case .folder(let id):
      let data = try await service.fetchBookmarkItems(id: "\(id)", page: page)
      return PageResult(cards: data.items.map(MediaCard.init), pagination: data.pagination)
    case .downloads:
      // Local files — `DownloadsView` owns that section, this catalog never fetches it.
      return PageResult(cards: [], pagination: nil)
    }
  }

  /// `/v1/watching/*` sends only enough to draw a card. Serials carry episode counts
  /// (progress + "+N new"); films carry neither.
  private nonisolated static func card(for item: WatchingItem, isSeries: Bool) -> MediaCard {
    MediaCard(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              progress: isSeries ? item.progress : nil,
              badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
              backdropURL: item.posters.wideURL ?? item.posters.big,
              isSeries: isSeries,
              isInWatchlist: isSeries)
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task { await self?.load(force: false) }
    }.store(in: &bag)
  }
}
