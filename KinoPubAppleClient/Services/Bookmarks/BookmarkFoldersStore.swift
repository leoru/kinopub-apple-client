//
//  BookmarkFoldersStore.swift
//  KinoPubAppleClient
//
//  The account's bookmark folders, kept across launches.
//
//  Opening a title used to fire `GET /v1/bookmarks` twice — once for the hero's folder
//  menu, once for the card menus on the same page — for a list that only changes when
//  the viewer creates or deletes a folder. Nothing on a detail page *needs* the call:
//  whether the title is bookmarked comes from the item payload (`MediaItem.bookmarks`)
//  and `BookmarkMembershipStore`; the folder list is only names for a menu.
//
//  So: detail pages read this store and never fetch. The screens that list folders
//  anyway (Library, Bookmarks, the sidebar) hand their result back with `adopt(_:)`,
//  and anything that creates or deletes a folder calls `reload(using:)`.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

@MainActor
final class BookmarkFoldersStore: ObservableObject {

  static let shared = BookmarkFoldersStore()

  /// Last known folder list, in the order the server returned it. Restored from disk at
  /// launch so a cold detail page can draw a full folder menu without a request.
  @Published private(set) var folders: [Bookmark] = []

  private let defaults: UserDefaults
  private let defaultsKey = "com.soda.kinopub.bookmarkFolders"
  /// Set by `invalidate()` — the list on hand is known to be behind the account.
  private var needsRefresh = false
  private var inFlight: Task<[Bookmark]?, Never>?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    load()
  }

  /// Folders for a menu, fetching only when there is nothing to show (a cold install)
  /// or the list is known to be stale. Concurrent callers share the one request.
  @discardableResult
  func ensureLoaded(using service: VideoContentService) async -> [Bookmark] {
    guard folders.isEmpty || needsRefresh else { return folders }
    return await reload(using: service)
  }

  /// Fetch unconditionally — for right after a folder is created or removed.
  @discardableResult
  func reload(using service: VideoContentService) async -> [Bookmark] {
    if let inFlight {
      _ = await inFlight.value
      return folders
    }
    let task = Task<[Bookmark]?, Never> {
      do {
        return try await service.fetchBookmarks().items
      } catch {
        Logger.app.debug("Bookmark folders load failed: \(error)")
        return nil
      }
    }
    inFlight = task
    let fetched = await task.value
    inFlight = nil
    // A failure keeps whatever we had — an empty menu is worse than a slightly old one —
    // and leaves `needsRefresh` set so the next caller tries again.
    if let fetched { adopt(fetched) }
    return folders
  }

  /// Take the list from a screen that fetched it for its own reasons. Pass the raw
  /// server list, before any display filtering: a folder with no items is still a
  /// folder the viewer can add this title to.
  func adopt(_ fetched: [Bookmark]) {
    needsRefresh = false
    guard fetched != folders else { return }
    folders = fetched
    persist()
  }

  /// Mark the list stale after a mutation, without blanking the menus in the meantime.
  func invalidate() {
    needsRefresh = true
  }

  func clear() {
    needsRefresh = false
    folders = []
    defaults.removeObject(forKey: defaultsKey)
  }

  // MARK: - Persistence

  private func load() {
    guard let data = defaults.data(forKey: defaultsKey),
          let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else { return }
    folders = decoded
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(folders) else { return }
    defaults.set(data, forKey: defaultsKey)
  }
}
