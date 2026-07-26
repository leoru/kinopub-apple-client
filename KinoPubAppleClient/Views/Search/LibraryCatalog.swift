//
//  LibraryCatalog.swift
//  KinoPubAppleClient
//

import Foundation
import Combine
import KinoPubBackend
import KinoPubLogging
import OSLog

/// The Search tab's listing: a search when there is a query, the filtered catalog
/// otherwise. Both feed the same paginated grid.
@MainActor
class LibraryCatalog: ObservableObject {

  @Published public var items: [MediaItem] = []
  /// True while the first page is on its way. Starts `true` so Search can paint
  /// its placeholder grid on the first frame; paging further down never sets it.
  @Published public private(set) var isLoading: Bool = true
  @Published public var query: String = ""
  @Published public var filter: LibraryFilter = LibraryFilter()

  /// Picker contents, loaded once the user is authorized.
  @Published public private(set) var genres: [MediaGenre] = []
  @Published public private(set) var countries: [Country] = []

  private var pagination: Pagination?
  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var bag = Set<AnyCancellable>()

  var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       filter: LibraryFilter = LibraryFilter()) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.filter = filter
    subscribe()
  }

  // MARK: - Loading

  func load() async {
    guard authState.userState == .authorized else {
      isLoading = false
      subscribeForAuth()
      return
    }

    // A person's credits show a sort control and nothing else, so their pickers would
    // be two requests for lists nobody can open.
    if filter.person == nil, genres.isEmpty || countries.isEmpty {
      await loadPickerData()
    }

    let isFirstPage = pagination == nil
    if isFirstPage { isLoading = true }
    defer { isLoading = false }

    do {
      let page = pagination.map { $0.current + 1 }
      let data: PaginatedData<MediaItem>
      if isSearching {
        data = try await itemsService.search(query: query, page: page)
      } else {
        data = try await itemsService.fetchItems(filter: filter, page: page)
      }
      handle(data, isFirstPage: isFirstPage)
    } catch {
      Logger.app.error("Library fetch failed: \(error)")
      errorHandler.setError(error)
    }
  }

  /// Pickers are chrome: if they fail the listing still works, so this never raises.
  private func loadPickerData() async {
    async let genresTask = try? itemsService.fetchGenres(for: filter.contentType).items
    async let countriesTask = try? itemsService.fetchCountries().items
    genres = (await genresTask ?? []).sorted { $0.title < $1.title }
    countries = (await countriesTask ?? []).sorted { $0.title < $1.title }
  }

  private func handle(_ data: PaginatedData<MediaItem>, isFirstPage: Bool) {
    if isFirstPage {
      items = data.items
    } else {
      items.append(contentsOf: data.items)
    }
    pagination = data.pagination
  }

  func loadMoreContent(after item: MediaItem) {
    guard let pagination else { return }
    let thresholdIndex = items.index(items.endIndex, offsetBy: -1)
    if thresholdIndex == items.firstIndex(of: item), pagination.current < pagination.total {
      Task { await load() }
    }
  }

  func refresh() async {
    isLoading = true
    items = []
    pagination = nil
    errorHandler.reset()
    await load()
  }

  // MARK: - Filter changes

  func applyExternalFilter(_ filter: LibraryFilter) {
    query = ""
    self.filter = filter
    genres = []
    Task { await refresh() }
  }

  func update(_ transform: (inout LibraryFilter) -> Void) {
    var updated = filter
    transform(&updated)
    guard updated != filter else { return }
    let typeChanged = updated.contentType != filter.contentType
    filter = updated
    // Genres are per content type, so a type change invalidates the list — and any
    // genre picked from the old one.
    if typeChanged {
      genres = []
      self.filter.genreID = nil
    }
    Task { await refresh() }
  }

  func clearFilters() {
    guard filter.hasActiveFilters else { return }
    filter = LibraryFilter(sort: filter.sort)
    genres = []
    Task { await refresh() }
  }

  // MARK: - Subscriptions

  private func subscribe() {
    $query
      .dropFirst()
      .removeDuplicates()
      .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        Task { await self?.refresh() }
      }.store(in: &bag)
  }

  private func subscribeForAuth() {
    authState.$userState.filter { $0 == .authorized }
      .first()
      .removeDuplicates()
      .sink { [weak self] _ in
        Task { await self?.refresh() }
      }.store(in: &bag)
  }
}
