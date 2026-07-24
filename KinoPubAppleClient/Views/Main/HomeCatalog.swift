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
  @Published public private(set) var isLoaded: Bool = false

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var actionsService: UserActionsService
  private var bag = Set<AnyCancellable>()

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.actionsService = actionsService
  }

  func fetch() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    async let continueWatching = fetchContinueWatchingRow()
    async let shortcutRows = fetchShortcutRows()

    var assembled: [MediaRow] = []
    if let row = await continueWatching {
      assembled.append(row)
    }
    assembled.append(contentsOf: await shortcutRows)

    rows = assembled
    isLoaded = true
  }

  func refresh() async {
    isLoaded = false
    errorHandler.reset()
    await fetch()
  }

  // MARK: - Continue watching actions

  /// Clears history for the title and drops it from the row immediately.
  func hide(_ card: MediaCard) {
    removeFromContinueWatching(cardID: card.id)
    Task {
      do {
        try await actionsService.clearHistoryForItem(id: card.itemID)
      } catch {
        errorHandler.setError(error)
        await fetch()
      }
    }
  }

  /// Marks the resume point's episode (or the film) watched, then removes the card —
  /// Continue Watching has nothing left to offer for a finished title.
  func toggleWatched(_ card: MediaCard) {
    guard let video = card.video else { return }
    removeFromContinueWatching(cardID: card.id)
    Task {
      do {
        try await actionsService.toggleWatching(id: card.itemID, video: video, season: card.season)
      } catch {
        errorHandler.setError(error)
        await fetch()
      }
    }
  }

  private func removeFromContinueWatching(cardID: Int) {
    guard let index = rows.firstIndex(where: { $0.id == Self.continueWatchingRowID }) else { return }
    let row = rows[index]
    let cards = row.cards.filter { $0.id != cardID }
    if cards.isEmpty {
      rows.remove(at: index)
    } else {
      rows[index] = MediaRow(id: row.id, title: row.title, count: row.count, cards: cards, destination: row.destination)
    }
  }

  // MARK: - Continue watching

  private func fetchContinueWatchingRow() async -> MediaRow? {
    async let moviesTask = try? itemsService.fetchWatchingMovies().items
    async let allSerialsTask = try? itemsService.fetchWatchingSerials(subscribedOnly: false).items
    async let watchlistTask = try? itemsService.fetchWatchingSerials(subscribedOnly: true).items
    async let historyTask = try? itemsService.fetchHistory().history

    let movies = await moviesTask ?? []
    let serials = await allSerialsTask ?? []
    let watchlist = await watchlistTask ?? []
    let history = await historyTask ?? []

    let watchlistIDs = Set(watchlist.map(\.id))
    let lastSeen = ContinueWatchingOrder.lastSeenByItemID(history)
    let newestEntry = Self.newestEntryByItemID(history)
    let historyIDs = Set(history.map(\.item.id))

    var pool = ContinueWatchingOrder.mergePool(movies: movies, serials: serials, watchlist: watchlist)

    // Titles only present in recent history still belong in "recently started".
    let now = Date()
    for entry in history {
      guard let date = entry.lastSeenDate,
            now.timeIntervalSince(date) <= ContinueWatchingOrder.recentWindow,
            !pool.contains(where: { $0.id == entry.item.id }),
            let item = WatchingItem(historyEntry: entry) else { continue }
      pool.append(item)
    }

    let ordered = ContinueWatchingOrder.ordered(items: pool,
                                                watchlistIDs: watchlistIDs,
                                                lastSeen: lastSeen)

    let cards = ordered.map {
      Self.card(for: $0,
                history: newestEntry[$0.id],
                isInHistory: historyIDs.contains($0.id),
                isInWatchlist: watchlistIDs.contains($0.id))
    }
    guard !cards.isEmpty else { return nil }

    return MediaRow(id: Self.continueWatchingRowID,
                    title: "Continue Watching".localized,
                    cards: cards)
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
  /// S/E label and resume bar.
  private static func card(for item: WatchingItem,
                           history: HistoryEntry?,
                           isInHistory: Bool,
                           isInWatchlist: Bool) -> MediaCard {
    let isSeries = item.type.contains("serial")
    let video: Int?
    let season: Int?
    if let history, history.isEpisode {
      video = history.media?.number
      season = history.media?.snumber
    } else if !isSeries {
      video = history?.media?.number ?? 1
      season = nil
    } else {
      video = history?.media?.number
      season = history?.media?.snumber
    }

    return MediaCard(id: item.id,
                     posterURL: item.posters.medium,
                     title: item.localizedTitle,
                     subtitle: item.originalTitle,
                     progress: history?.progress ?? item.progress,
                     badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
                     backdropURL: landscapeImageURL(for: item, history: history),
                     metaLine: overlayLabel(for: history),
                     landscapeImageURL: landscapeImageURL(for: item, history: history),
                     overlayLabel: overlayLabel(for: history),
                     itemID: item.id,
                     video: video,
                     season: season,
                     mediaID: history?.media?.id,
                     isWatched: false,
                     isSeries: isSeries,
                     isInHistory: isInHistory,
                     isInWatchlist: isInWatchlist)
  }

  private static func landscapeImageURL(for item: WatchingItem, history: HistoryEntry?) -> String {
    history?.item.posters?.wideURL ?? item.posters.wideURL ?? item.posters.big
  }

  private static func overlayLabel(for history: HistoryEntry?) -> String? {
    guard let history else { return nil }
    var parts: [String] = []
    if history.isEpisode, let season = history.media?.snumber, let episode = history.media?.number {
      parts.append("S\(season), E\(episode)")
    }
    if let duration = history.media?.duration, duration >= 60 {
      parts.append(Duration.hoursMinutes(seconds: duration))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  // MARK: - Catalog shortcuts

  private func fetchShortcutRows() async -> [MediaRow] {
    await withTaskGroup(of: (Int, MediaRow?).self) { group in
      for (index, shortcut) in Self.shortcuts.enumerated() {
        group.addTask { [itemsService] in
          do {
            let data = try await itemsService.fetch(shortcut: shortcut.shortcut,
                                                    contentType: shortcut.contentType,
                                                    page: nil)
            let cards = data.items.map(Self.card(for:))
            guard !cards.isEmpty else { return (index, nil) }
            return (index, MediaRow(id: shortcut.id, title: shortcut.title.localized, cards: cards))
          } catch {
            Logger.app.error("Failed to load row \(shortcut.id): \(error)")
            return (index, nil)
          }
        }
      }

      // Task groups finish out of order; restore the declared row order.
      var collected: [(Int, MediaRow)] = []
      for await (index, row) in group {
        if let row { collected.append((index, row)) }
      }
      return collected.sorted { $0.0 < $1.0 }.map(\.1)
    }
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
