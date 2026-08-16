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
  /// A page past the first is in flight.
  @Published private(set) var isLoadingMore = false

  /// What the grid footer should say. `.complete` needs a `pagination` to be sure —
  /// the unpaginated sections never reach it and stay `.idle`.
  var paginationState: PaginationState {
    if isLoadingMore { return PaginationState(phase: .loading, loadedCount: cards.count) }
    if paginationFailed { return PaginationState(phase: .failed, loadedCount: cards.count) }
    guard section.isPaginated, let pagination, pagination.current >= pagination.total
    else { return .idle }
    return PaginationState(phase: .complete, loadedCount: cards.count)
  }

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

  /// Raw history *entries* per request. History is one row per play, and under
  /// `HistoryGrouping.byShow` those collapse to one card per title — so a page of 20
  /// entries can easily be three cards for someone part-way through a season. 50 keeps
  /// the grid filling in one round trip instead of three.
  ///
  /// Deliberately **not** used by the launch path: `HomeCatalog` still asks for 20,
  /// because that request rides in the cold-start burst where a 96 KB page was already
  /// called out as too much.
  static let historyPerPage = 50

  /// A page that adds nothing new must not end the list, but chasing it forever is
  /// worse. Three consecutive all-duplicate pages and we stop until the user scrolls
  /// again.
  private static let emptyPageBudget = 3

  private func loadPage(_ page: Int) async {
    guard !isFetchingPage else { return }
    isFetchingPage = true
    defer { isFetchingPage = false }
    isLoadingMore = true
    defer { isLoadingMore = false }

    var page = page
    var barren = 0

    while true {
      let section = self.section
      do {
        let result = try await Self.page(page, of: section, using: contentService)
        guard section == self.section else { return }

        // Appending blind put duplicate ids into the grid, where `ForEach` keeps the
        // first and silently drops the rest: three requests, nothing new on screen —
        // and, because the last card never changed, its `onAppear` kept asking. Still
        // needed with grouping off: two pages can carry the same play, and ids are
        // synthesised from the entry precisely so identical plays collide here.
        let known = Set(cards.map(\.id))
        let fresh = result.cards.filter { !known.contains($0.id) }

        pagedCards.append(contentsOf: fresh)
        pagination = result.pagination
        paginationFailed = false
        publishCards()

        guard fresh.isEmpty else { return }
        // Nothing new, and the threshold card is unchanged — no further `onAppear`
        // will fire, so the grid would sit there looking finished. Walk forward
        // ourselves rather than stalling.
        barren += 1
        guard barren < Self.emptyPageBudget,
              let pagination, pagination.current < pagination.total else { return }
        page = pagination.current + 1
      } catch {
        guard section == self.section else { return }
        paginationFailed = true
        Logger.app.debug("Library section page \(page) failed, keeping loaded cards: \(error)")
        errorHandler.setError(error)
        return
      }
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
      let data = try await service.fetchHistory(page: page, perPage: historyPerPage)
      return PageResult(cards: HistoryView.cards(from: data.history, grouping: HistoryGrouping.current),
                        pagination: data.pagination)
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
