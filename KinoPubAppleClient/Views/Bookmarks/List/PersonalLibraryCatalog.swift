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
  /// True when nothing could be loaded and there's no cache to show — the view swaps
  /// the blank screen for a retry state. Cached rows always win over this flag.
  @Published public private(set) var loadFailed: Bool = false
  /// The failure behind `loadFailed`, so the retry state can say what actually went wrong.
  @Published public private(set) var loadError: Error?

  /// The folder *list* itself (ids, titles, counts) isn't row-cached — it's one
  /// cheap call, and we need it live to know which folders even exist. Only the
  /// per-folder item fetch (the N-per-folder fanout) goes through the store.
  private var folders: [Bookmark] = []
  private var foldersFetchFailed = false
  private var foldersError: Error?

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
        await store.refreshIfStale(.watchlist) { [weak self] in //'weak' ownership of capture 'self' differs from implicitly-captured strong reference in outer scope
          guard let self else { throw CancellationError() }
          return try await self.fetchWatchlistCards()
        }
      }
      group.addTask { [store] in
        await store.refreshIfStale(.history) { [weak self] in // 'weak' ownership of capture 'self' differs from implicitly-captured strong reference in outer scope
          guard let self else { throw CancellationError() }
          return try await self.fetchHistoryCards()
        }
      }
      for folder in folders {
        group.addTask { [store] in
          await store.refreshIfStale(.folder(folder.id)) { [weak self] in // 'weak' ownership of capture 'self' differs from implicitly-captured strong reference in outer scope
            guard let self else { throw CancellationError() }
            return try await self.fetchFolderCards(folder)
          }
        }
      }
    }

    assembleRows()
    isLoaded = true
    let firstError = [self.store.lastError(.watchlist), self.store.lastError(.history)].lazy
      .compactMap { $0 }
      .first
    loadFailed = rows.isEmpty && (foldersFetchFailed || firstError != nil)
    loadError = rows.isEmpty ? (firstError ?? foldersError) : nil
  }

  /// Pull-to-refresh: forces every row to refetch regardless of TTL.
  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    loadFailed = false
    loadError = nil
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
    let history = try await contentService.fetchHistory(page: nil, perPage: 20).history
    // Always collapsed here: this is a preview shelf, and twenty cards of the same
    // series in a row would crowd out every other title the user has watched.
    return HistoryView.cards(from: history, grouping: .byShow)
  }

  private func fetchFolders() async -> [Bookmark] {
    do {
      let all = try await contentService.fetchBookmarks().items
      // Unfiltered into the shared store — see BookmarksCatalog.
      BookmarkFoldersStore.shared.adopt(all)
      let fetched = all
        .filter { $0.count != "0" }
        .recentlyUpdatedFirst()
      foldersFetchFailed = false
      foldersError = nil
      return fetched
    } catch {
      Logger.app.debug("Library bookmarks failed: \(error)")
      foldersFetchFailed = true
      foldersError = error
      return folders  // keep whatever we already knew rather than emptying the tab
    }
  }

  private func fetchFolderCards(_ folder: Bookmark) async throws -> [MediaCard] {
    try await contentService.fetchBookmarkItems(id: "\(folder.id)", page: nil).items.map(MediaCard.init)
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task { await self?.fetch() }
    }.store(in: &bag)
  }
}
