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

  /// Empty until the first fetch lands — the screen shows a spinner rather than
  /// stand-in artwork, the way the Apple TV app waits.
  @Published public private(set) var rows: [MediaRow] = []
  /// Up to six contained banner cards sampled from the catalog shelves below.
  @Published public private(set) var bannerCards: [MediaCard] = []
  @Published public private(set) var isLoaded: Bool = false

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var actionsService: UserActionsService
  private var store: ContentStore
  private var bag = Set<AnyCancellable>()

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService,
       store: ContentStore = AppContext.shared.contentStore) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.actionsService = actionsService
    self.store = store
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

    await withTaskGroup(of: Void.self) { group in
      group.addTask { [store] in
        await store.refreshIfStale(.continueWatching) { [weak self] in
          guard let self else { throw CancellationError() }
          return try await self.fetchContinueWatchingCards()
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
  }

  /// Pull-to-refresh: forces every row to refetch regardless of TTL.
  func refresh() async {
    errorHandler.reset()
    store.invalidate(family: .watch)
    store.invalidate(family: .catalog)
    await fetch()
  }

  private func assembleRows() {
    var assembled: [MediaRow] = []
    let continueWatchingCards = store.cards(.continueWatching)
    if !continueWatchingCards.isEmpty {
      assembled.append(MediaRow(id: Self.continueWatchingRowID,
                                title: "Continue Watching".localized,
                                cards: continueWatchingCards))
    }
    for shortcut in Self.shortcuts {
      let cards = store.cards(.shortcut(shortcut.shortcut, shortcut.contentType))
      guard !cards.isEmpty else { continue }
      assembled.append(MediaRow(id: shortcut.id, title: shortcut.title.localized, cards: cards))
    }
    rows = assembled
    refreshBannerCards(from: assembled)
  }

  /// v1 hack: up to six unique titles drawn at random from the catalog shelves
  /// (not Continue Watching). Prefer cards that already carry wide artwork.
  /// Keeps the previous selection when most of it is still in the pool so a
  /// background refresh does not reshuffle the banner under the remote.
  private func refreshBannerCards(from rows: [MediaRow]) {
    var seen = Set<Int>()
    var pool: [MediaCard] = []
    for row in rows where row.id != Self.continueWatchingRowID {
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
    AppContext.shared.localProgressStore.clear(id: card.itemID)
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
    AppContext.shared.localProgressStore.clear(id: card.itemID)
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
    async let historyTask = try? itemsService.fetchHistory().history

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
    let historyIDs = Set(history.map(\.item.id))
    let localEntries = AppContext.shared.localProgressStore.allEntries()
    let localByID = Dictionary(uniqueKeysWithValues: localEntries.map { ($0.id, $0) })

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
    for entry in localEntries where !entry.watch.isFinished {
      lastSeen[entry.id] = Date(timeIntervalSince1970: entry.updatedAt)
      if !pool.contains(where: { $0.id == entry.id }) {
        pool.append(WatchingItem(mediaItem: entry.item))
      }
    }

    // Drop server-listed titles that local progress already considers finished.
    pool.removeAll { localByID[$0.id]?.watch.isFinished == true }

    let ordered = ContinueWatchingOrder.ordered(items: pool,
                                                watchlistIDs: watchlistIDs,
                                                lastSeen: lastSeen)

    return ordered.map {
      Self.card(for: $0,
                history: newestEntry[$0.id],
                local: localByID[$0.id],
                isInHistory: historyIDs.contains($0.id) || localByID[$0.id] != nil,
                isInWatchlist: watchlistIDs.contains($0.id))
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
                           history: HistoryEntry?,
                           local: LocalWatchEntry?,
                           isInHistory: Bool,
                           isInWatchlist: Bool) -> MediaCard {
    let isSeries = item.type.contains("serial")
    let video: Int?
    let season: Int?
    if let local, let localSeason = local.season, let localEpisode = local.episode {
      video = localEpisode
      season = localSeason
    } else if let history, history.isEpisode {
      video = history.media?.number
      season = history.media?.snumber
    } else if !isSeries {
      video = history?.media?.number ?? local?.episode ?? 1
      season = nil
    } else {
      video = history?.media?.number ?? local?.episode
      season = history?.media?.snumber ?? local?.season
    }

    let localFraction = local?.watch.isResumable == true ? local?.watch.fraction : nil
    let progress = [localFraction, history?.progress, item.progress].compactMap { $0 }.max()

    return MediaCard(id: item.id,
                     posterURL: item.posters.medium,
                     title: item.localizedTitle,
                     subtitle: item.originalTitle,
                     progress: progress,
                     badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
                     backdropURL: landscapeImageURL(for: item, history: history, local: local),
                     metaLine: overlayLabel(for: history, local: local),
                     landscapeImageURL: landscapeImageURL(for: item, history: history, local: local),
                     overlayLabel: overlayLabel(for: history, local: local),
                     itemID: item.id,
                     video: video,
                     season: season,
                     mediaID: history?.media?.id,
                     isWatched: false,
                     isSeries: isSeries,
                     isInHistory: isInHistory,
                     isInWatchlist: isInWatchlist)
  }

  private static func landscapeImageURL(for item: WatchingItem,
                                        history: HistoryEntry?,
                                        local: LocalWatchEntry?) -> String {
    history?.item.posters?.wideURL
      ?? local?.item.posters.wideURL
      ?? item.posters.wideURL
      ?? item.posters.big
  }

  private static func overlayLabel(for history: HistoryEntry?, local: LocalWatchEntry?) -> String? {
    var parts: [String] = []
    if let history, history.isEpisode,
       let season = history.media?.snumber, let episode = history.media?.number {
      parts.append("S\(season), E\(episode)")
    } else if let season = local?.season, let episode = local?.episode {
      parts.append("S\(season), E\(episode)")
    }
    if let duration = history?.media?.duration, duration >= 60 {
      parts.append(Duration.hoursMinutes(seconds: duration))
    } else if let duration = local?.duration, duration >= 60 {
      parts.append(Duration.hoursMinutes(seconds: Int(duration)))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  // MARK: - Catalog shortcuts

  private func fetchShortcutCards(_ shortcut: Shortcut) async throws -> [MediaCard] {
    let data = try await itemsService.fetch(shortcut: shortcut.shortcut,
                                             contentType: shortcut.contentType,
                                             page: nil)
    return data.items.map(Self.card(for:))
  }

  private static func card(for item: MediaItem) -> MediaCard {
    MediaCard(item)
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
