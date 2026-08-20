//
//  LibraryCatalog.swift
//  KinoPubAppleClient
//

import Foundation
import Combine
import KinoPubBackend
import KinoPubUI
import KinoPubLogging
import OSLog

/// The Search tab's listing: a search when there is a query, the filtered catalog
/// otherwise. Both feed the same paginated grid.
///
/// # How a query actually reaches the server
///
/// Read this before touching anything in the search path — the pieces live in four
/// files and the order they wake up in is load-bearing.
///
/// **Two endpoints, one grid.** `isSearching` (a non-blank `query`) picks
/// `/v1/items/search?q=`; otherwise it is `/v1/items` with `filter`. There is no third
/// mode. If results look like an arbitrary catalogue rather than the query, the query
/// never arrived and this fell through to the filtered branch — that is the failure to
/// look for first, not a ranking problem on the server. The genre / country requests
/// you see beside it are `loadPickerData()`, which runs for the filter pickers on the
/// first page and is unrelated to searching.
///
/// **Where the text comes from is not the same on every platform.**
/// - iOS / iPadOS / tvOS: `.searchable` is inside `SearchView`, bound to its own
///   `@State`. The view exists before the field does, so nothing can race.
/// - macOS: the field is in the *window toolbar* (`macToolbarSearch`), bound to
///   `NavigationState.macSearchFieldText`, and it exists on every tab — including tabs
///   where `SearchView` is not mounted at all. Typing there is what mounts it.
///
/// **The macOS trap, and why this init takes a query.** `SearchView` reads the field
/// through `onChange`, which by definition only fires for changes made *after* the view
/// is on screen. The user's text is already in the toolbar field before the search
/// surface mounts, so on the first frame `query` was empty, `.task` called `load()`,
/// and the grid filled with the unfiltered catalogue — for every entry, Return
/// included. Only the *next* keystroke reached it. Hence `query:` here: the catalog is
/// born already searching, before `subscribe()` can see the value, so no duplicate
/// refresh is queued behind the first load either.
///
/// **The debounce is not the entry point.** `subscribe()` gives `$query` 0.5 s and then
/// refreshes, which handles typing into an already-mounted view. It cannot start a
/// search on a view that does not exist. Mounting is
/// `NavigationState.beginToolbarSearchIfNeeded()`, on the first non-blank character.
@MainActor
class LibraryCatalog: ObservableObject {

  @Published public var items: [MediaItem] = []
  /// True while the first page is on its way. Starts `true` so Search can paint
  /// its placeholder grid on the first frame; paging further down never sets it.
  @Published public private(set) var isLoading: Bool = true
  /// True after the first page fails — the grid has nothing to show, so the view
  /// swaps to a retry state.
  @Published public private(set) var loadFailed: Bool = false
  /// The failure behind `loadFailed`, so the retry state can say what actually went wrong.
  @Published public private(set) var loadError: Error?
  /// True when a page past the first failed — loaded items stay on screen and the
  /// grid offers an inline retry at the bottom instead of swapping to an error screen.
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
  @Published public var query: String = ""
  @Published public var filter: LibraryFilter = LibraryFilter()

  /// Picker contents, loaded once the user is authorized.
  @Published public private(set) var genres: [MediaGenre] = []
  @Published public private(set) var countries: [Country] = []
  @Published public private(set) var pagination: Pagination?
  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var bag = Set<AnyCancellable>()
  private var isFetching = false

  var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

  /// `query` is for the surface that already holds the user's text when this is built
  /// — the macOS toolbar field. Assigned before `subscribe()` on purpose: `$query`
  /// emits its current value to a new subscriber, and `dropFirst()` there swallows
  /// exactly that, so seeding costs no extra refresh. See the type's doc comment.
  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       filter: LibraryFilter = LibraryFilter(),
       query: String = "") {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.filter = filter
    self.query = query
    subscribe()
  }

  // MARK: - Loading

  func load() async {
    guard authState.userState == .authorized else {
      isLoading = false
      subscribeForAuth()
      return
    }

    let isFirstPage = pagination == nil
    // Pagination triggers fire per visible cell — drop duplicates while a page is
    // already on its way. First-page loads (refresh, filter change) always run.
    if !isFirstPage {
      guard !isFetching else { return }
    }
    isFetching = true
    defer { isFetching = false }
    // Only pages after the first: the first page owns the full-screen loading state.
    isLoadingMore = !isFirstPage
    defer { isLoadingMore = false }

    // A person's credits show a sort control and nothing else, so their pickers would
    // be two requests for lists nobody can open.
    if filter.person == nil, genres.isEmpty || countries.isEmpty {
      await loadPickerData()
    }

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
      loadFailed = false
      loadError = nil
      paginationFailed = false
    } catch {
      if isFirstPage {
        items = []
        loadFailed = true
        loadError = error
        Logger.app.error("Library first page fetch failed: \(error)")
      } else {
        paginationFailed = true
        Logger.app.debug("Library page fetch failed, keeping loaded items: \(error)")
        errorHandler.setError(error)
      }
    }
  }

  /// Retries the page that failed — the grid and its scroll position stay as they are.
  func retryPagination() {
    paginationFailed = false
    Task { await load() }
  }

  /// Pickers are chrome: if they fail the listing still works, so this never raises.
  private func loadPickerData() async {
    async let genresTask = try? itemsService.fetchGenres(for: filter.contentType).items
    async let countriesTask = try? itemsService.fetchCountries().items
    genres = (await genresTask ?? []).sorted { $0.title < $1.title }
    countries = (await countriesTask ?? []).sorted { $0.title < $1.title }
  }

  /// A person's credits are the one listing where the same film arrives twice — the 3D
  /// encoding is its own entry under the same name — so they get one card per film.
  /// The library grid and search do not: there a type filter of "3D" is a request for
  /// exactly those entries. Collapsing runs over everything loaded so far, since the
  /// second copy of a film can land a page later.
  private func handle(_ data: PaginatedData<MediaItem>, isFirstPage: Bool) {
    let loaded = isFirstPage ? data.items : items + data.items
    items = filter.person != nil && !isSearching ? loaded.collapsingFilmVariants() : loaded
    pagination = data.pagination
  }

  func loadMoreContent(after item: MediaItem) {
    guard let pagination else { return }
    // O(1) by id — never firstIndex(of:), which deep-compares MediaItem.
    guard CatalogLoadMore.isThresholdItem(item, in: items),
          pagination.current < pagination.total else {
      return
    }
    Task { await load() }
  }

  func refresh() async {
    isLoading = true
    loadFailed = false
    loadError = nil
    paginationFailed = false
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
