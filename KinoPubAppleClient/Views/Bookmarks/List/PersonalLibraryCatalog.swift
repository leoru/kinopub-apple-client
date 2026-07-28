//
//  PersonalLibraryCatalog.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import KinoPubUI
import OSLog
import KinoPubLogging
import Combine

/// Watchlist + history + bookmark folders as rows — the combined Library tab on
/// tvOS / iOS / iPad. (Search keeps its own `LibraryCatalog`.)
@MainActor
class PersonalLibraryCatalog: ObservableObject {

  private var authState: AuthState
  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var store: ContentStore
  private var bag = Set<AnyCancellable>()

  @Published public private(set) var rows: [MediaRow] = []
  @Published public private(set) var isLoaded: Bool = false

  /// The folder *list* itself (ids, titles, counts) isn't row-cached — it's one
  /// cheap call, and we need it live to know which folders even exist. Only the
  /// per-folder item fetch (the N-per-folder fanout) goes through the store.
  private var folders: [Bookmark] = []

  init(itemsService: VideoContentService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       store: ContentStore = AppContext.shared.contentStore) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.store = store
  }

  func fetch() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    folders = await fetchFolders()
    assembleRows()
    isLoaded = !rows.isEmpty

    await withTaskGroup(of: Void.self) { group in
      group.addTask { [store] in
        await store.refreshIfStale(.watchlist) { [weak self] in
          guard let self else { throw CancellationError() }
          return try await self.fetchWatchlistCards()
        }
      }
      group.addTask { [store] in
        await store.refreshIfStale(.history) { [weak self] in
          guard let self else { throw CancellationError() }
          return try await self.fetchHistoryCards()
        }
      }
      for folder in folders {
        group.addTask { [store] in
          await store.refreshIfStale(.folder(folder.id)) { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.fetchFolderCards(folder)
          }
        }
      }
    }

    assembleRows()
    isLoaded = true
  }

  /// Pull-to-refresh: forces every row to refetch regardless of TTL.
  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    store.invalidate(family: .watch)
    store.invalidate(family: .bookmarks)
    await fetch()
  }

  private func assembleRows() {
    var assembled: [MediaRow] = []

    let watchlistCards = store.cards(.watchlist)
    if !watchlistCards.isEmpty {
      assembled.append(MediaRow(id: "watchlist",
                                title: "Watchlist".localized,
                                count: "\(watchlistCards.count)",
                                cards: watchlistCards))
    }

    let historyCards = store.cards(.history)
    if !historyCards.isEmpty {
      assembled.append(MediaRow(id: "history",
                                title: "Recently Watched".localized,
                                count: "\(historyCards.count)",
                                cards: historyCards))
    }

    for folder in folders {
      let cards = store.cards(.folder(folder.id))
      guard !cards.isEmpty else { continue }
      assembled.append(MediaRow(id: "bookmark-\(folder.id)",
                                title: folder.title,
                                count: folder.count,
                                cards: cards,
                                destination: BookmarksRoutes.bookmark(folder)))
    }

    rows = assembled
  }

  private func fetchWatchlistCards() async throws -> [MediaCard] {
    let items = try await contentService.fetchWatchingSerials(subscribedOnly: true).items
    return items.map { item in
      MediaCard(id: item.id,
               posterURL: item.posters.medium,
               title: item.localizedTitle,
               subtitle: item.originalTitle,
               badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
               backdropURL: item.posters.wideURL ?? item.posters.big)
    }
  }

  private func fetchHistoryCards() async throws -> [MediaCard] {
    let history = try await contentService.fetchHistory().history
    return HistoryView.cards(from: history)
  }

  private func fetchFolders() async -> [Bookmark] {
    do {
      return try await contentService.fetchBookmarks().items
        .filter { $0.count != "0" }
        .recentlyUpdatedFirst()
    } catch {
      Logger.app.debug("Library bookmarks failed: \(error)")
      errorHandler.setError(error)
      return folders  // keep whatever we already knew rather than emptying the tab
    }
  }

  private func fetchFolderCards(_ folder: Bookmark) async throws -> [MediaCard] {
    try await contentService.fetchBookmarkItems(id: "\(folder.id)").items.map(MediaCard.init)
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task { await self?.fetch() }
    }.store(in: &bag)
  }
}
