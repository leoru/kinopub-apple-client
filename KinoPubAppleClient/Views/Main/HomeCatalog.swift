//
//  HomeCatalog.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import KinoPubUI
import OSLog
import KinoPubLogging
import Combine

/// Builds the home screen's rows: what the user is part-way through first, then the
/// catalog shortcuts. Rows that come back empty are dropped rather than shown blank.
@MainActor
class HomeCatalog: ObservableObject {

  struct Shortcut {
    let shortcut: MediaShortcut
    let contentType: MediaType
    let title: String

    var id: String { "\(shortcut.rawValue)-\(contentType.rawValue)" }
  }

  /// The catalog rows below "Continue watching", in display order.
  static let shortcuts: [Shortcut] = [
    Shortcut(shortcut: .hot, contentType: .movie, title: "Hot Movies"),
    Shortcut(shortcut: .hot, contentType: .serial, title: "Hot Series"),
    Shortcut(shortcut: .fresh, contentType: .movie, title: "Fresh Movies"),
    Shortcut(shortcut: .fresh, contentType: .serial, title: "Fresh Series"),
    Shortcut(shortcut: .popular, contentType: .movie, title: "Popular Movies"),
    Shortcut(shortcut: .popular, contentType: .serial, title: "Popular Series")
  ]

  static let continueWatchingRowID = "continue-watching"
  static let collectionsRowID = "collections"

  /// How far a horizontal shelf has been paged, per row id.
  ///
  /// Home rows used to be one page each, forever: `fetch(… page: nil)` and the
  /// `pagination` block thrown away. This is the state that was missing — without it
  /// there is nowhere to record "page 3 of 40" or "a request is already in flight",
  /// and a near-end signal has nothing to act on.
  private struct PageCursor {
    var loaded: Int
    var total: Int
    var isLoading = false
    var didFail = false

    var hasMore: Bool { loaded < total }
  }

  /// `@Published` so a shelf redraws its tail tile when paging starts, fails or runs
  /// out — the cursor was private state until it had something to say on screen.
  @Published private var cursors: [String: PageCursor] = [:]

  /// What the shelf for `rowID` should be showing at its trailing edge.
  func paginationState(rowID: String, loadedCount: Int) -> PaginationState {
    guard rowID != Self.continueWatchingRowID, let cursor = cursors[rowID] else {
      // Continue Watching is not paginated, so it is never mid-load and never "all of
      // it" — it is simply a list.
      return .idle
    }
    if cursor.isLoading { return PaginationState(phase: .loading, loadedCount: loadedCount) }
    if cursor.didFail { return PaginationState(phase: .failed, loadedCount: loadedCount) }
    if !cursor.hasMore { return PaginationState(phase: .complete, loadedCount: loadedCount) }
    return .idle
  }

  /// The tail tile's retry. Clears the failure so `loadMore` stops declining.
  func retryPagination(rowID: String) {
    cursors[rowID]?.didFail = false
    loadMore(rowID: rowID)
  }

  /// Empty until the first fetch lands — the screen shows a spinner rather than
  /// stand-in artwork, the way the Apple TV app waits.
  @Published public private(set) var rows: [MediaRow] = []
  /// Up to six contained banner cards sampled from the catalog shelves below.
  @Published public private(set) var bannerCards: [MediaCard] = []
  @Published public private(set) var isLoaded: Bool = false
  /// True when every shelf failed and there is nothing cached to show — the view
  /// swaps the blank screen for a retry state. Cached rows always win over this flag.
  @Published public private(set) var loadFailed: Bool = false
  /// The failure behind `loadFailed`, so the retry state can say what actually went
  /// wrong (an expired session is not a connection problem).
  @Published public private(set) var loadError: Error?

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var actionsService: UserActionsService
  private var collectionsService: CollectionsService
  private var store: ContentStore
  private var localProgressStore: LocalWatchProgressStore
  private var bag = Set<AnyCancellable>()

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService,
       collectionsService: CollectionsService = AppContext.shared.collectionsService,
       store: ContentStore = AppContext.shared.contentStore,
       localProgressStore: LocalWatchProgressStore = AppContext.shared.localProgressStore) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.actionsService = actionsService
    self.collectionsService = collectionsService
    self.store = store
    self.localProgressStore = localProgressStore
    NotificationCenter.default.publisher(for: .localWatchProgressDidChange)
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.assembleRows()
      }
      .store(in: &bag)
  }

  /// Paints whatever's cached immediately (instant on a warm cache, still empty on a
  /// cold one — same first-launch behaviour as before), then refreshes in the
  /// background only the rows whose TTL expired. A return trip within the TTL costs
  /// zero requests.
  func fetch() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    assembleRows()
    isLoaded = !rows.isEmpty

    let collectionsNeedMigration = store.cards(.collections).contains { !$0.opensCollection }

    await withTaskGroup(of: Void.self) { group in
      group.addTask { [store] in
        await store.refreshIfStale(.continueWatching) { [weak self] in
          guard let self else { throw CancellationError() }
          return try await self.fetchContinueWatchingCards()
        }
      }
      group.addTask { [store] in
        // Stale snapshots predate `opensCollection` — force a refresh so Select
        // opens the collection rather than a colliding media id.
        if collectionsNeedMigration {
          await store.refresh(.collections) { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.fetchCollectionsPreviewCards()
          }
        } else {
          await store.refreshIfStale(.collections) { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.fetchCollectionsPreviewCards()
          }
        }
      }
      for shortcut in Self.shortcuts {
        group.addTask { [store] in
          await store.refreshIfStale(.shortcut(shortcut.shortcut, shortcut.contentType)) { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.fetchShortcutCards(shortcut)
          }
        }
      }
    }

    assembleRows()
    isLoaded = true
    // Catalog shelves always have content when the network cooperates, so an empty
    // screen with at least one failed shelf means an outage, not an empty account.
    let firstError = Self.shortcuts.lazy
      .compactMap { self.store.lastError(.shortcut($0.shortcut, $0.contentType)) }
      .first
    loadFailed = rows.isEmpty && firstError != nil
    loadError = rows.isEmpty ? firstError : nil
  }

  // MARK: - Paging a horizontal shelf

  /// The user scrolled a shelf to its last loaded card. Fetches the next page and
  /// appends it, or does nothing when there is nothing left.
  ///
  /// **Continue Watching never pages.** It is not one endpoint with pages: it is a
  /// merge of `watching/movies`, `watching/serials` (twice) and `history`, ordered by
  /// what the user touched last. "Page 2" of that has no meaning on the server.
  func loadMore(rowID: String) {
    guard rowID != Self.continueWatchingRowID else { return }
    guard var cursor = cursors[rowID], cursor.hasMore, !cursor.isLoading, !cursor.didFail
    else { return }

    cursor.isLoading = true
    cursors[rowID] = cursor
    let next = cursor.loaded + 1

    Task { [weak self] in
      guard let self else { return }
      defer { self.cursors[rowID]?.isLoading = false }
      do {
        let cards = try await self.fetchPage(next, ofRow: rowID)
        guard !cards.isEmpty else {
          // Server says there is another page and hands back nothing: stop asking,
          // rather than retrying on every scroll to the end for the rest of the session.
          self.cursors[rowID]?.total = self.cursors[rowID]?.loaded ?? next
          return
        }
        self.store.appendCards(cards, for: try self.storeKey(forRow: rowID))
        self.cursors[rowID]?.loaded = next
        self.cursors[rowID]?.didFail = false
        self.assembleRows()
      } catch {
        // The cursor stays where it was, so a retry asks for the same page again. It is
        // flagged rather than silently retried on the next scroll: a failed page that
        // looks like the end of the catalogue is the thing being fixed here.
        self.cursors[rowID]?.didFail = true
        Logger.app.debug("HomeCatalog: page \(next) of \(rowID) failed: \(error)")
      }
    }
  }

  private func fetchPage(_ page: Int, ofRow rowID: String) async throws -> [MediaCard] {
    if rowID == Self.collectionsRowID {
        let data = try await collectionsService.fetchCollections(page: page, sort: "views-")
      return data.collections.map(CollectionMediaCard.make(from:))
    }
    guard let shortcut = Self.shortcuts.first(where: { $0.id == rowID }) else { return [] }
    let data = try await itemsService.fetch(shortcut: shortcut.shortcut,
                                            contentType: shortcut.contentType,
                                            page: page)
    return data.items.map(Self.card(for:))
  }

  private func storeKey(forRow rowID: String) throws -> RowKey {
    if rowID == Self.collectionsRowID { return .collections }
    guard let shortcut = Self.shortcuts.first(where: { $0.id == rowID }) else {
      throw CancellationError()
    }
    return .shortcut(shortcut.shortcut, shortcut.contentType)
  }

  /// Pull-to-refresh: forces every row to refetch regardless of TTL.
  func refresh() async {
    errorHandler.reset()
    loadFailed = false
    loadError = nil
    store.invalidate(family: .watch)
    store.invalidate(family: .catalog)
    // A refresh returns every shelf to page 1, so the cursors have to go back with it —
    // otherwise a row that had reached page 5 would ask for page 6 of a one-page row.
    cursors.removeAll()
    await fetch()
  }

  /// Re-apply local resume onto the cached Continue Watching row. Cheap: no
  /// network. Home's `.task` does not re-run when returning from the player
  /// (`NavigationStack` root stays mounted), so this is also the appear path.
  func repaintFromLocalProgress() {
    assembleRows()
  }

  private func assembleRows() {
    var assembled: [MediaRow] = []
    let continueWatchingCards = paintedContinueWatchingCards()
    if !continueWatchingCards.isEmpty {
      assembled.append(MediaRow(id: Self.continueWatchingRowID,
                                title: "Continue Watching".localized,
                                cards: continueWatchingCards))
    }
    for shortcut in Self.shortcuts {
      let cards = store.cards(.shortcut(shortcut.shortcut, shortcut.contentType))
      guard !cards.isEmpty else { continue }
      // Same chevron + "see all" the Collections row already has: the header pushes a
      // full paginated grid pinned to this shortcut. tvOS ignores `destination` (a row
      // header is never a focus stop there) — see `MediaPosterShelf`.
      assembled.append(MediaRow(id: shortcut.id,
                                title: shortcut.title.localized,
                                cards: cards,
                                destination: Route.shortcutItems(shortcut.shortcut,
                                                                 shortcut.contentType,
                                                                 title: shortcut.title.localized)))
    }
    // Collections sit last — a catalog add-on, not mixed into the hot/fresh/popular band.
    let collectionsCards = store.cards(.collections)
    if !collectionsCards.isEmpty {
      assembled.append(MediaRow(id: Self.collectionsRowID,
                                title: "Collections".localized,
                                cards: collectionsCards,
                                destination: Route.collections))
    }
    rows = assembled
    refreshBannerCards(from: assembled)
  }

  /// Read-time overlay: `ContentStore` still holds the last server snapshot (and its
  /// TTL). Local progress paints the bar, hides a just-finished film, and steps a
  /// series to the next episode without rewriting `rows-v2.json` on every player tick.
  private func paintedContinueWatchingCards() -> [MediaCard] {
    let stored = store.cards(.continueWatching)
    let entries = localProgressStore.allEntries()
    let locals = entries.map { entry in
      ContinueWatchingLocalOverlay.Local(
        itemID: entry.id,
        isSeries: entry.item.isEpisodicType || entry.season != nil,
        season: entry.season,
        episode: entry.episode,
        isFinished: entry.watch.isFinished,
        isResumable: entry.watch.isResumable,
        progress: entry.watch.resumeFraction,
        updatedAt: entry.updatedAt,
        canInsert: true
      )
    }
    let plan = ContinueWatchingLocalOverlay.plan(
      cards: stored.map {
        ContinueWatchingLocalOverlay.Card(itemID: $0.itemID,
                                          isSeries: $0.isSeries,
                                          season: $0.season,
                                          video: $0.video)
      },
      locals: locals
    )
    let storedByID = Dictionary(stored.map { ($0.itemID, $0) }, uniquingKeysWith: { _, last in last })
    let entryByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    return plan.order.compactMap { id -> MediaCard? in
      let base: MediaCard?
      if plan.insertIDs.contains(id), let entry = entryByID[id] {
        base = Self.card(for: WatchingItem(mediaItem: entry.item),
                         detail: nil,
                         history: nil,
                         finishedEpisodes: [:],
                         local: entry,
                         isInHistory: true,
                         isInWatchlist: false,
                         cached: nil)
      } else {
        base = storedByID[id]
      }
      guard let base else { return nil }
      guard let mutation = plan.mutations[id] else { return base }
      return base.withContinueWatching(progress: mutation.progress,
                                       season: mutation.season,
                                       video: mutation.video,
                                       overlayLabel: mutation.overlayLabel)
    }
  }

  /// v1 hack: up to six unique titles drawn at random from the catalog shelves
  /// (not Continue Watching). Prefer cards that already carry wide artwork.
  /// Keeps the previous selection when most of it is still in the pool so a
  /// background refresh does not reshuffle the banner under the remote.
  /// Skipped entirely when `FeatureFlags.homeBannerEnabled` is off — no sampling and
  /// therefore no wide-poster fetches from `HomeBannerCardView`.
  private func refreshBannerCards(from rows: [MediaRow]) {
    guard FeatureFlags.homeBannerEnabled else {
      if !bannerCards.isEmpty { bannerCards = [] }
      return
    }

    var seen = Set<Int>()
    var pool: [MediaCard] = []
    for row in rows where row.id != Self.continueWatchingRowID && row.id != Self.collectionsRowID {
      for card in row.cards where seen.insert(card.id).inserted {
        pool.append(card)
      }
    }

    let preferred = pool.filter { $0.backdropURL != nil }
    let source = preferred.isEmpty ? pool : preferred
    let sourceIDs = Set(source.map(\.id))

    let kept = bannerCards.filter { sourceIDs.contains($0.id) }
    if kept.count >= min(3, source.count), !source.isEmpty {
      var next = kept
      if next.count < 6 {
        let missing = source.filter { card in !next.contains(where: { $0.id == card.id }) }
        next.append(contentsOf: missing.shuffled().prefix(6 - next.count))
      }
      bannerCards = Array(next.prefix(6))
      return
    }

    bannerCards = Array(source.shuffled().prefix(6))
  }

  // MARK: - Continue watching actions

  /// Clears history for the title and drops it from the row immediately — the store
  /// mutation is the source of truth `assembleRows()` reads back, so no local `rows`
  /// bookkeeping is needed here anymore.
  func hide(_ card: MediaCard) {
    store.removeCard(id: card.id, from: .continueWatching)
    localProgressStore.clear(id: card.itemID)
    assembleRows()
    Task {
      do {
        try await actionsService.clearHistoryForItem(id: card.itemID)
      } catch {
        errorHandler.setError(error)
        store.invalidate(family: .watch)
        await fetch()
      }
    }
  }

  /// Marks the resume point's episode (or the film) watched, then removes the card —
  /// Continue Watching has nothing left to offer for a finished title.
  func toggleWatched(_ card: MediaCard) {
    guard let video = card.video else { return }
    store.removeCard(id: card.id, from: .continueWatching)
    localProgressStore.clear(id: card.itemID)
    assembleRows()
    Task {
      do {
        try await actionsService.toggleWatching(id: card.itemID, video: video, season: card.season)
      } catch {
        errorHandler.setError(error)
        store.invalidate(family: .watch)
        await fetch()
      }
    }
  }

  // MARK: - Continue watching

  private func fetchContinueWatchingCards() async throws -> [MediaCard] {
    async let moviesTask = try? itemsService.fetchWatchingMovies().items
    async let allSerialsTask = try? itemsService.fetchWatchingSerials(subscribedOnly: false).items
    async let watchlistTask = try? itemsService.fetchWatchingSerials(subscribedOnly: true).items
    async let historyTask = try? itemsService.fetchHistory(page: nil, perPage: 20).history

    let moviesResult = await moviesTask
    let serialsResult = await allSerialsTask
    let watchlistResult = await watchlistTask
    let historyResult = await historyTask

    // Each source degrades independently (one endpoint down still shows the other
    // three) — but if every single one failed, this is a network outage, not "the
    // user has nothing to continue watching". Throw so the store keeps the last
    // known-good row instead of caching an empty one.
    if moviesResult == nil, serialsResult == nil, watchlistResult == nil, historyResult == nil {
      throw ContinueWatchingFetchError.allSourcesFailed
    }

    let movies = moviesResult ?? []
    let serials = serialsResult ?? []
    let watchlist = watchlistResult ?? []
    let history = historyResult ?? []

    let watchlistIDs = Set(watchlist.map(\.id))
    var lastSeen = ContinueWatchingOrder.lastSeenByItemID(history)
    let newestEntry = Self.newestEntryByItemID(history)
    let finishedEpisodes = Self.finishedEpisodesByItemID(history)
    let historyIDs = Set(history.map(\.item.id))
    let localEntries = localProgressStore.allEntries()
    let localByID = Dictionary(uniqueKeysWithValues: localEntries.map { ($0.id, $0) })
    let cached = store.cards(.continueWatching)
    let cachedByID = Dictionary(cached.map { ($0.itemID, $0) }, uniquingKeysWith: { _, last in last })

    var pool = ContinueWatchingOrder.mergePool(movies: movies, serials: serials, watchlist: watchlist)

    // Titles only present in recent history still belong in "recently started".
    // Drop finished rows (watched to credits) so they don't invite a resume.
    let now = Date()
    for entry in history {
      if let watch = entry.watchProgress, watch.isFinished { continue }
      guard let date = entry.lastSeenDate,
            now.timeIntervalSince(date) <= ContinueWatchingOrder.recentWindow,
            !pool.contains(where: { $0.id == entry.item.id }),
            let item = WatchingItem(historyEntry: entry) else { continue }
      pool.append(item)
    }

    // Locally-started titles (> 10s) the backend doesn't list yet.
    // Finished films stay out. Finished series stay only if a server source still
    // lists them — re-inserting would invent E+1 after the title left watching.
    for entry in localEntries {
      if entry.watch.isFinished {
        if entry.item.isEpisodicType || entry.season != nil {
          lastSeen[entry.id] = Date(timeIntervalSince1970: entry.updatedAt)
        }
        continue
      }
      lastSeen[entry.id] = Date(timeIntervalSince1970: entry.updatedAt)
      if !pool.contains(where: { $0.id == entry.id }) {
        pool.append(WatchingItem(mediaItem: entry.item))
      }
    }

    // Drop server-listed films that local progress already considers finished.
    // Series stay: finishing an episode is not finishing the title.
    pool.removeAll { item in
      guard let local = localByID[item.id], local.watch.isFinished else { return false }
      return !item.type.contains("serial")
    }

    let ordered = ContinueWatchingOrder.ordered(items: pool,
                                                watchlistIDs: watchlistIDs,
                                                lastSeen: lastSeen)

    let details = await seriesDetails(for: ordered, cached: cached)

    return ordered.compactMap {
      Self.card(for: $0,
                detail: details[$0.id],
                history: newestEntry[$0.id],
                finishedEpisodes: finishedEpisodes[$0.id] ?? [:],
                local: localByID[$0.id],
                isInHistory: historyIDs.contains($0.id) || localByID[$0.id] != nil,
                isInWatchlist: watchlistIDs.contains($0.id),
                cached: cachedByID[$0.id])
    }
  }

  /// How many series the row will fetch payloads for. Continue Watching is short by
  /// design, and this is the ceiling on what one refresh of it costs.
  private static let seriesDetailLimit = 12

  /// The series behind the cards, because **only the title itself knows where its
  /// seasons end and which episodes the server counts as watched.** Without it the row
  /// offered "S1, E9" on an eight-episode season (nothing to play at all) and re-offered
  /// an episode whose last five minutes were credits.
  ///
  /// One request per **new** series. A card that already carries the offered S/E from
  /// the last snapshot is trusted — that is why the row caches those fields — so a
  /// TTL refresh does not refetch up to `seriesDetailLimit` details. Films need
  /// none of this: they have one video. Past the cap, titles with no cached S/E still
  /// fall back to history counters.
  private func seriesDetails(for items: [WatchingItem], cached: [MediaCard]) async -> [Int: MediaItem] {
    let cachedByID = Dictionary(cached.map { ($0.itemID, $0) }, uniquingKeysWith: { _, last in last })
    var ids: [Int] = []
    for item in items where item.type.contains("serial") {
      if let card = cachedByID[item.id], card.season != nil, card.video != nil {
        continue
      }
      ids.append(item.id)
      if ids.count >= Self.seriesDetailLimit { break }
    }
    guard !ids.isEmpty else { return [:] }

    return await withTaskGroup(of: (Int, MediaItem?).self) { group in
      for id in ids {
        group.addTask { [itemsService] in
          let item = try? await itemsService.fetchDetails(
            for: "\(id)",
            excludeLinks: FeatureFlags.seriesDetailsWithoutLinks
          ).item
          // Every `/v1/watching*` call keys on the item id, and an episode only carries
          // it once its season has been stamped — see `Episode.metadata`.
          item?.seasons?.forEach { $0.mediaId = item?.id }
          return (id, item)
        }
      }
      var byID: [Int: MediaItem] = [:]
      for await (id, item) in group {
        if let item { byID[id] = item }
      }
      return byID
    }
  }

  /// Item id → season → the episodes that season's history rows ran to the credits.
  /// The full picture history can give, rather than only its most recent row.
  private static func finishedEpisodesByItemID(_ history: [HistoryEntry]) -> [Int: [Int: Set<Int>]] {
    history.reduce(into: [Int: [Int: Set<Int>]]()) { result, entry in
      guard entry.isEpisode,
            entry.watchProgress?.isFinished == true,
            let season = entry.media?.snumber,
            let number = entry.media?.number else { return }
      result[entry.item.id, default: [:]][season, default: []].insert(number)
    }
  }

  private static func newestEntryByItemID(_ history: [HistoryEntry]) -> [Int: HistoryEntry] {
    history.reduce(into: [Int: HistoryEntry]()) { result, entry in
      guard let date = entry.lastSeenDate else { return }
      if let existing = result[entry.item.id], let seen = existing.lastSeenDate, seen >= date { return }
      result[entry.item.id] = entry
    }
  }

  /// Continue-watching cards are landscape wide covers — episode stills are too
  /// anonymous to recognise a title from across the room. History still supplies the
  /// S/E label and resume bar; local progress fills gaps before the server catches up.
  private static func card(for item: WatchingItem,
                           detail: MediaItem?,
                           history: HistoryEntry?,
                           finishedEpisodes: [Int: Set<Int>],
                           local: LocalWatchEntry?,
                           isInHistory: Bool,
                           isInWatchlist: Bool,
                           cached: MediaCard?) -> MediaCard? {
    let isSeries = item.type.contains("serial")
    let video: Int?
    let season: Int?
    // True while the viewer is mid-video: only then do a progress bar and a "N left"
    // label belong on the card. A film is always "resuming" — there is one video.
    var isResuming = true

    if isSeries {
      // The newest history row is where the viewer *was*, not what to play next: on a
      // finished episode this offered it again, with its full runtime under it.
      if let detail, detail.isSeries {
        // The title's own answer, and the same one the detail page's Play button gives —
        // first episode the server does not count as watched, across season boundaries.
        // `playAgain` means there is no such episode: every one of them is watched, and
        // a finished series has no business in Continue Watching.
        guard detail.playbackAction != .playAgain,
              let (nextSeason, episode) = detail.primaryEpisode else { return nil }
        video = episode.number
        season = nextSeason.number
        isResuming = episode.watchProgress.isResumable
      } else if let cached, cached.season != nil, cached.video != nil {
        // Trusted offered S/E from the last snapshot — do not re-guess from counters
        // just because this refresh skipped the details call.
        if let local, let episode = local.episode, !local.watch.isFinished {
          video = episode
          season = local.season
          isResuming = true
        } else if let local, local.watch.isFinished {
          let currentSeason = history?.media?.snumber ?? local.season ?? cached.season
          let next = ContinueWatchingEpisode.forSeries(
            local: (local.season, local.episode, true),
            history: history.map { ($0.media?.snumber, $0.media?.number, $0.watchProgress?.isFinished ?? false) },
            finishedInSeason: currentSeason.flatMap { finishedEpisodes[$0] } ?? [],
            watchedCount: item.watched,
            total: item.total
          )
          guard next.hasEpisode || (item.new ?? 0) > 0 else { return nil }
          video = next.episode
          season = next.season
          isResuming = next.isResuming
        } else {
          video = cached.video
          season = cached.season
          isResuming = cached.progress != nil
        }
      } else {
        // No payload for this one (request failed, or past the fetch cap): fall back to
        // what history and the counters can say. Which season the viewer is in, and
        // everything history says they finished in it — history is ordered by when a
        // row was played, so the newest row is not the furthest episode.
        let currentSeason = history?.media?.snumber ?? local?.season
        let next = ContinueWatchingEpisode.forSeries(
          local: local.map { ($0.season, $0.episode, $0.watch.isFinished) },
          history: history.map { ($0.media?.snumber, $0.media?.number, $0.watchProgress?.isFinished ?? false) },
          finishedInSeason: currentSeason.flatMap { finishedEpisodes[$0] } ?? [],
          watchedCount: item.watched,
          total: item.total
        )
        // Every episode watched and nothing new announced — the row is done with.
        guard next.hasEpisode || (item.new ?? 0) > 0 else { return nil }
        video = next.episode
        season = next.season
        isResuming = next.isResuming
      }
    } else {
      video = history?.media?.number ?? local?.episode ?? 1
      season = nil
    }

    // The episode the card actually offers, when the payload gave us one — its own
    // progress and runtime, not the previous episode's.
    let offered = detail?.seasons?
      .first { $0.number == season }?.episodes
      .first { $0.number == video }
    let localFraction = local?.watch.resumeFraction
    // Episode resume only — never serial watched/total (that is not a scrubber) — and
    // never the *previous* episode's progress under a fresh one.
    let episodeProgress = isResuming
      ? (offered?.watchProgress.fraction ?? localFraction ?? history?.progress)
      : nil
    let durationSeconds = offered.map(\.duration)
      ?? (isResuming
          ? (cached?.durationSeconds ?? Self.durationSeconds(history: history, local: local))
          : nil)
    let overlay = Self.overlayLabel(isSeries: isSeries, season: season, episode: video)
    let newCount = item.new.flatMap { $0 > 0 ? $0 : nil }

    return MediaCard(id: item.id,
                     posterURL: item.posters.medium,
                     title: item.localizedTitle,
                     subtitle: item.originalTitle,
                     progress: episodeProgress,
                     badge: newCount.map { "+\($0)" },
                     backdropURL: landscapeImageURL(for: item, history: history, local: local),
                     metaLine: overlay,
                     landscapeImageURL: landscapeImageURL(for: item, history: history, local: local),
                     overlayLabel: overlay,
                     itemID: item.id,
                     video: video,
                     season: season,
                     mediaID: isResuming ? history?.media?.id : nil,
                     isWatched: false,
                     isSeries: isSeries,
                     isInHistory: isInHistory,
                     isInWatchlist: isInWatchlist,
                     durationSeconds: durationSeconds,
                     primaryAction: .play)
  }

  private static func durationSeconds(history: HistoryEntry?, local: LocalWatchEntry?) -> Int? {
    if let duration = history?.media?.duration, duration >= 60 { return duration }
    if let duration = local?.duration, duration >= 60 { return Int(duration) }
    return nil
  }

  /// Continue Watching used to reach straight for the title's wide poster and never
  /// look at the episode still it already had — so a row of series showed derived
  /// `/item/wide/` URLs, many of which 404, beside History's real stills. Same rule
  /// for both surfaces now; the fallback to a 2:3 `big` poster is gone, because
  /// cropping one into a 16:9 box is what made the row look ragged.
  private static func landscapeImageURL(for item: WatchingItem,
                                        history: HistoryEntry?,
                                        local: LocalWatchEntry?) -> String? {
    MediaCard.landscapeArtwork(
      episodeStill: history?.media?.thumbnail,
      posters: history?.item.posters ?? local?.item.posters ?? item.posters,
      isSeries: item.type.contains("serial")
    )
  }

  /// Says whichever episode the card is actually offering — it used to derive its own
  /// S/E from history and could disagree with the one Play would open.
  private static func overlayLabel(isSeries: Bool, season: Int?, episode: Int?) -> String? {
    guard isSeries else { return nil }
    return ContinueWatchingEpisode.overlayLabel(season: season, episode: episode)
  }

  // MARK: - Catalog shortcuts

  private func fetchShortcutCards(_ shortcut: Shortcut) async throws -> [MediaCard] {
    let data = try await itemsService.fetch(shortcut: shortcut.shortcut,
                                             contentType: shortcut.contentType,
                                             page: nil)
    // Page 1 is also where we learn how many there are — the only place the API says so.
    cursors[shortcut.id] = PageCursor(loaded: 1, total: max(data.pagination.total, 1))
    return data.items.map(Self.card(for:))
  }

  private static func card(for item: MediaItem) -> MediaCard {
    BookmarkMembershipStore.shared.seed(from: item)
    return MediaCard(item)
  }

  // MARK: - Collections

  /// First page of curated collections, as poster tiles — `/v1/collections` ships
  /// each collection's own artwork + counters (no per-collection item fetch).
  private func fetchCollectionsPreviewCards() async throws -> [MediaCard] {
    let data = try await collectionsService.fetchCollections(page: nil, sort: "views-")
    cursors[Self.collectionsRowID] = PageCursor(loaded: 1,
                                                total: max(data.pagination?.total ?? 1, 1))
    // No longer capped at twelve: the row pages like the catalogue shelves now, and a
    // hard cap would have been the thing stopping it. `Route.collections` stays as the
    // full grid for anyone who would rather not scroll sideways.
    return data.collections.map(CollectionMediaCard.make(from:))
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

private enum ContinueWatchingFetchError: Error {
  /// All four underlying calls (movies/serials/watchlist/history) failed — a real
  /// outage, not "nothing to continue watching". Signals `ContentStore` to keep the
  /// cached row instead of overwriting it with an empty one.
  case allSourcesFailed
}
