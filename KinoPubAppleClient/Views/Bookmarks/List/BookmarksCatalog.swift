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

  @Published public private(set) var rows: [MediaRow] = BookmarksCatalog.placeholderRows()

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

      rows = folders.map(Self.placeholderRow(for:))
      await fillRows(for: folders)
      // A folder the service still counts but returns nothing for would draw as a bare
      // title over empty space.
      rows = rows.filter { !$0.cards.isEmpty }
    } catch {
      Logger.app.debug("fetch bookmarks error: \(error)")
      errorHandler.setError(error)
    }
  }

  /// Rows show their real titles as soon as the folder list lands, then each swaps its
  /// placeholder cards for artwork as its own request comes back.
  private func fillRows(for folders: [Bookmark]) async {
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
        guard rows.indices.contains(index) else { continue }
        rows[index] = Self.row(for: folders[index], items: items)
      }
    }
  }

  @Sendable @MainActor
  func refresh() async {
    rows = Self.placeholderRows()
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

  private static func placeholderRow(for bookmark: Bookmark) -> MediaRow {
    MediaRow(id: rowID(for: bookmark),
             title: bookmark.title,
             count: bookmark.count,
             cards: placeholderCards(),
             destination: BookmarksRoutes.bookmark(bookmark))
  }

  private static func placeholderRows() -> [MediaRow] {
    (0..<3).map { index in
      MediaRow(id: "placeholder-\(index)",
               title: " ",
               cards: placeholderCards(),
               isPlaceholder: true)
    }
  }

  private static func placeholderCards() -> [MediaCard] {
    (0..<6).map { index in
      MediaCard(id: index, posterURL: "", title: " ", subtitle: " ", isPlaceholder: true)
    }
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task {
        await self?.refresh()
      }
    }.store(in: &bag)
  }

}
