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

/// Builds the Bookmarks overview: one row per folder with artwork. Watchlist lives
/// on its own sidebar tab now. Folder rows read through `ContentStore`, so a warm
/// cache paints instantly and a failed refresh keeps the last known folders instead
/// of blanking the tab.
@MainActor
class BookmarksCatalog: ObservableObject {

  private var authState: AuthState
  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var store: ContentStore
  private var bag = Set<AnyCancellable>()

  /// Empty until the first folder lands; the screen shows a spinner until then
  /// rather than stand-in artwork.
  @Published public private(set) var rows: [MediaRow] = []
  @Published public private(set) var isLoaded: Bool = false
  /// True when the folder list failed and there's no cache to show — the view swaps
  /// the blank screen for a retry state. Cached rows always win over this flag.
  @Published public private(set) var loadFailed: Bool = false
  /// The failure behind `loadFailed`, so the retry state can say what actually went wrong.
  @Published public private(set) var loadError: Error?

  /// The folder list isn't row-cached — it's one cheap call, and we need it live to
  /// know which folders even exist. On failure the previous list stays.
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

  func fetchItems() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }

    await fetchFolders()

    // Cached rows first — instant paint on a warm store, still empty on a cold one.
    assembleRows()
    isLoaded = !rows.isEmpty

    await withTaskGroup(of: Void.self) { group in
      for folder in folders {
        group.addTask { [store, contentService] in
          await store.refreshIfStale(.folder(folder.id)) {
            let items = try await contentService.fetchBookmarkItems(id: "\(folder.id)", page: nil).items
            return items.map(MediaCard.init)
          }
          // Each folder's row appears as soon as its own fetch lands.
          await self.assembleRows()
        }
      }
    }

    assembleRows()
    isLoaded = true
    let firstError = folders.lazy.compactMap { self.store.lastError(.folder($0.id)) }.first
    loadFailed = rows.isEmpty && (foldersFetchFailed || firstError != nil)
    loadError = rows.isEmpty ? (firstError ?? foldersError) : nil
  }

  private func fetchFolders() async {
    do {
      let fetched = try await contentService.fetchBookmarks().items
      // Unfiltered into the shared store: an empty folder is still one you can file a
      // title in from a card menu, even though this screen has nothing to draw for it.
      BookmarkFoldersStore.shared.adopt(fetched)
      folders = fetched
        .filter { $0.count != "0" }
        .recentlyUpdatedFirst()
      foldersFetchFailed = false
      foldersError = nil
    } catch {
      Logger.app.debug("fetch bookmarks error: \(error)")
      foldersFetchFailed = true
      foldersError = error
    }
  }

  /// A folder the service still counts but returns nothing for never draws — a bare
  /// title over empty space is worse than no row at all.
  private func assembleRows() {
    rows = folders.compactMap { folder in
      let cards = store.cards(.folder(folder.id))
      guard !cards.isEmpty else { return nil }
      return Self.row(for: folder, cards: cards)
    }
  }

  @Sendable @MainActor
  func refresh() async {
    errorHandler.reset()
    loadFailed = false
    loadError = nil
    store.invalidate(family: .bookmarks)
    Logger.app.debug("refetch bookmarks")
    await fetchItems()
  }

  // MARK: - Rows

  private static func rowID(for bookmark: Bookmark) -> String { "bookmark-\(bookmark.id)" }

  private static func row(for bookmark: Bookmark, cards: [MediaCard]) -> MediaRow {
    MediaRow(id: rowID(for: bookmark),
             title: bookmark.title,
             count: bookmark.count,
             cards: cards,
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
