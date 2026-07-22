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

/// Builds the Saved screen as one row per bookmark folder, so the artwork is on screen
/// straight away instead of behind a list of folder names.
@MainActor
class BookmarksCatalog: ObservableObject {

  private var authState: AuthState
  private var contentService: VideoContentService
  private var errorHandler: ErrorHandler
  private var bag = Set<AnyCancellable>()

  /// Empty until the folders and their contents land; the screen shows a spinner
  /// until then rather than stand-in artwork.
  @Published public private(set) var rows: [MediaRow] = []
  @Published public private(set) var isLoaded: Bool = false

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

    do {
      // Whichever folder was added to most recently leads, not whichever was created last.
      let folders = try await contentService.fetchBookmarks().items
        .filter { $0.count != "0" }
        .recentlyUpdatedFirst()

      await fillRows(for: folders)
    } catch {
      Logger.app.debug("fetch bookmarks error: \(error)")
      errorHandler.setError(error)
    }
    isLoaded = true
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
        rows = built.compactMap { $0 }
      }
    }
  }

  @Sendable @MainActor
  func refresh() async {
    rows = []
    isLoaded = false
    Logger.app.debug("refetch bookmarks")
    await fetchItems()
  }

  // MARK: - Rows

  private static func rowID(for bookmark: Bookmark) -> String { "bookmark-\(bookmark.id)" }

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
