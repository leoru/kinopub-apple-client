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
  private var bag = Set<AnyCancellable>()

  @Published public private(set) var rows: [MediaRow] = []
  @Published public private(set) var isLoaded: Bool = false

  private var watchlistRow: MediaRow?
  private var historyRow: MediaRow?
  private var folderRows: [MediaRow] = []

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  func fetch() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    async let watchlist = fetchWatchlistRow()
    async let history = fetchHistoryRow()
    async let folders = fetchFolders()

    watchlistRow = await watchlist
    publish()
    historyRow = await history
    publish()

    let folderList = await folders
    await fillFolderRows(for: folderList)
    folderRows = folderRows.filter { !$0.cards.isEmpty }
    publish()
    isLoaded = true
  }

  @Sendable @MainActor
  func refresh() async {
    watchlistRow = nil
    historyRow = nil
    folderRows = []
    rows = []
    isLoaded = false
    await fetch()
  }

  private func publish() {
    rows = [watchlistRow, historyRow].compactMap { $0 } + folderRows
  }

  private func fetchWatchlistRow() async -> MediaRow? {
    do {
      let items = try await contentService.fetchWatchingSerials(subscribedOnly: true).items
      guard !items.isEmpty else { return nil }
      return MediaRow(
        id: "watchlist",
        title: "Watchlist".localized,
        count: "\(items.count)",
        cards: items.map { item in
          MediaCard(id: item.id,
                    posterURL: item.posters.medium,
                    title: item.localizedTitle,
                    subtitle: item.originalTitle,
                    badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
                    backdropURL: item.posters.wideURL ?? item.posters.big)
        }
      )
    } catch {
      Logger.app.error("Library watchlist failed: \(error)")
      return nil
    }
  }

  private func fetchHistoryRow() async -> MediaRow? {
    do {
      let history = try await contentService.fetchHistory().history
      let cards = HistoryView.cards(from: history)
      guard !cards.isEmpty else { return nil }
      return MediaRow(
        id: "history",
        title: "Recently Watched".localized,
        count: "\(cards.count)",
        cards: cards
      )
    } catch {
      Logger.app.error("Library history failed: \(error)")
      return nil
    }
  }

  private func fetchFolders() async -> [Bookmark] {
    do {
      return try await contentService.fetchBookmarks().items
        .filter { $0.count != "0" }
        .recentlyUpdatedFirst()
    } catch {
      Logger.app.debug("Library bookmarks failed: \(error)")
      errorHandler.setError(error)
      return []
    }
  }

  private func fillFolderRows(for folders: [Bookmark]) async {
    var built = [MediaRow?](repeating: nil, count: folders.count)
    await withTaskGroup(of: (Int, [MediaItem]).self) { group in
      for (index, folder) in folders.enumerated() {
        group.addTask { [contentService] in
          do {
            let items = try await contentService.fetchBookmarkItems(id: "\(folder.id)").items
            return (index, items)
          } catch {
            return (index, [])
          }
        }
      }
      for await (index, items) in group {
        guard !items.isEmpty else { continue }
        built[index] = MediaRow(
          id: "bookmark-\(folders[index].id)",
          title: folders[index].title,
          count: folders[index].count,
          cards: items.map(MediaCard.init),
          destination: BookmarksRoutes.bookmark(folders[index])
        )
        folderRows = built.compactMap { $0 }
        publish()
      }
    }
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task { await self?.refresh() }
    }.store(in: &bag)
  }
}
