//
//  BookmarksCatalog.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import KinoPubBackend
import KinoPubUI
import OSLog
import KinoPubLogging
import Combine

/// Builds the Saved screen: the watchlist first, then one row per bookmark folder, so
/// the artwork is on screen straight away instead of behind a list of folder names.
@MainActor
class BookmarksCatalog: ObservableObject {

  static let watchlistRowID = "watchlist"

  private var authState: AuthState
  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var bag = Set<AnyCancellable>()

  /// Empty until the watchlist or the first folder lands; the screen shows a spinner
  /// until then rather than stand-in artwork.
  @Published public private(set) var rows: [MediaRow] = []
  @Published public private(set) var isLoaded: Bool = false

  /// The two halves of the screen are filled by separate requests that land at their own
  /// pace; keeping them apart means neither has to know the other's row indices.
  private var watchlistRow: MediaRow?
  private var folderRows: [MediaRow] = []

  init(itemsService: VideoContentService, authState: AuthState, errorHandler: ErrorHandler) {
    self.contentService = itemsService
    self.authState = authState
    self.errorHandler = errorHandler
  }

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    async let watchlistTask = fetchWatchlistRow()
    async let foldersTask = fetchFolders()

    // The row that matters most goes up as soon as it lands.
    watchlistRow = await watchlistTask
    publish()

    let folders = await foldersTask
    await fillRows(for: folders)
    // A folder the service still counts but returns nothing for would draw as a bare
    // title over empty space.
    folderRows = folderRows.filter { !$0.cards.isEmpty }
    publish()
    isLoaded = true
  }

  private func fetchFolders() async -> [Bookmark] {
    do {
      // Whichever folder was added to most recently leads, not whichever was created last.
      return try await contentService.fetchBookmarks().items
        .filter { $0.count != "0" }
        .recentlyUpdatedFirst()
    } catch {
      Logger.app.debug("fetch bookmarks error: \(error)")
      errorHandler.setError(error)
      return []
    }
  }

  /// The watchlist leads the screen: these are the serials the user is following for new
  /// episodes, which is worth more than a folder of films they gave up on. A failure here
  /// only costs the row — the folders below are still worth showing.
  ///
  /// The API's own order is kept: it is already newest episode first (see README), and
  /// nothing in the payload would let us rebuild that order ourselves.
  private func fetchWatchlistRow() async -> MediaRow? {
    do {
      let items = try await contentService.fetchWatchingSerials(subscribedOnly: true).items
      guard !items.isEmpty else { return nil }

      return MediaRow(id: Self.watchlistRowID,
                      title: "Watchlist".localized,
                      count: "\(items.count)",
                      cards: items.map(Self.card(for:)))
    } catch {
      Logger.app.error("Failed to load watchlist: \(error)")
      return nil
    }
  }

  /// Each folder appears as soon as its own request comes back, in folder order. A
  /// folder the service still counts but returns nothing for never draws — a bare
  /// title over empty space is worse than no row at all.
  private func fillRows(for folders: [Bookmark]) async {
    var built = [MediaRow?](repeating: nil, count: folders.count)

    await withTaskGroup(of: (Int, [MediaItem]).self) { group in
      for (index, folder) in folders.enumerated() {
        group.addTask { [contentService] in
          do {
            let items = try await contentService.fetchBookmarkItems(id: "\(folder.id)").items
            return (index, items)
          } catch {
            Logger.app.error("Failed to load bookmark folder \(folder.id): \(error)")
            return (index, [])
          }
        }
      }

      for await (index, items) in group {
        guard !items.isEmpty else { continue }
        built[index] = Self.row(for: folders[index], items: items)
        folderRows = built.compactMap { $0 }
        publish()
      }
    }
  }

  private func publish() {
    rows = [watchlistRow].compactMap { $0 } + folderRows
  }

  @Sendable @MainActor
  func refresh() async {
    watchlistRow = nil
    folderRows = []
    rows = []
    isLoaded = false
    Logger.app.debug("refetch bookmarks")
    await fetchItems()
  }

  // MARK: - Rows

  private static func rowID(for bookmark: Bookmark) -> String { "bookmark-\(bookmark.id)" }

  /// Watchlist cards stay portrait like the folders below them, with how far through the
  /// serial the user is and a "+2" badge when episodes are waiting.
  private static func card(for item: WatchingItem) -> MediaCard {
    MediaCard(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              progress: item.progress,
              badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
              backdropURL: item.posters.wideURL ?? item.posters.big)
  }

  private static func row(for bookmark: Bookmark, items: [MediaItem]) -> MediaRow {
    MediaRow(id: rowID(for: bookmark),
             title: bookmark.title,
             count: bookmark.count,
             cards: items.map(MediaCard.init),
             destination: BookmarksRoutes.bookmark(bookmark))
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
