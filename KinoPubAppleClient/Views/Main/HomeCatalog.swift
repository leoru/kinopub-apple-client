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

  @Published public private(set) var rows: [MediaRow] = HomeCatalog.placeholderRows()
  @Published public private(set) var isLoaded: Bool = false

  private var authState: AuthState
  private var errorHandler: ErrorHandler
  private var itemsService: VideoContentService
  private var bag = Set<AnyCancellable>()

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.itemsService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
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
    rows = Self.placeholderRows()
    isLoaded = false
    errorHandler.reset()
    await fetch()
  }

  // MARK: - Continue watching

  private func fetchContinueWatchingRow() async -> MediaRow? {
    async let moviesTask = try? itemsService.fetchWatchingMovies().items
    async let allSerialsTask = try? itemsService.fetchWatchingSerials(subscribedOnly: false).items
    async let watchlistTask = try? itemsService.fetchWatchingSerials(subscribedOnly: true).items
    async let historyTask = try? itemsService.fetchHistory().history

    let movies = await moviesTask ?? []
    let serials = await allSerialsTask ?? []
    let watchlistIDs = Set((await watchlistTask ?? []).map(\.id))
    let history = await historyTask ?? []
    let lastSeen = ContinueWatchingOrder.lastSeenByItemID(history)
    let newestEntry = Self.newestEntryByItemID(history)

    let ordered = ContinueWatchingOrder.ordered(items: serials + movies,
                                                watchlistIDs: watchlistIDs,
                                                lastSeen: lastSeen)

    let cards = ordered.map { Self.card(for: $0, history: newestEntry[$0.id]) }
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

  /// Continue-watching cards are landscape, showing where playback stopped. History
  /// supplies the episode still and the wide poster; `/v1/watching/*` has neither.
  private static func card(for item: WatchingItem, history: HistoryEntry?) -> MediaCard {
    MediaCard(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              progress: history?.progress ?? item.progress,
              badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
              landscapeImageURL: landscapeImageURL(for: item, history: history),
              overlayLabel: overlayLabel(for: history))
  }

  /// Wide cover art, the way microiptv stretches it as a backdrop. History carries
  /// the real wide URL; otherwise it is derived from the watching item's poster.
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
    MediaCard(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              imdbRating: item.imdbRating,
              kinopoiskRating: item.kinopoiskRating,
              isPlaceholder: item.skeleton ?? false)
  }

  // MARK: - Placeholders

  private static func placeholderRows() -> [MediaRow] {
    shortcuts.prefix(3).map { shortcut in
      MediaRow(id: shortcut.id,
               title: shortcut.title.localized,
               cards: (0..<6).map { index in
                 MediaCard(id: index, posterURL: "", title: " ", subtitle: " ", isPlaceholder: true)
               })
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
