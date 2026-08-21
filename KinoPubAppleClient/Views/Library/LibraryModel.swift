//
//  LibraryModel.swift
//  KinoPubAppleClient
//

import Foundation
import Combine
import KinoPubBackend
import KinoPubLogging
import OSLog

/// Owns the Library sidebar: which section is selected, and the bookmark folders
/// (with their counts) that follow the fixed sections. Section *contents* belong to
/// `LibrarySectionCatalog` — this type never fetches items.
@MainActor
final class LibraryModel: ObservableObject {

  @Published private(set) var folders: [Bookmark] = []
  /// Library always has a selection; `.watchlist` is the product default when there
  /// is nothing remembered or the remembered folder is gone.
  @Published var selection: LibrarySection = .watchlist
  @Published private(set) var foldersFailed = false
  @Published private(set) var foldersError: Error?

  /// New-folder alert state, driven from the sidebar's "Create bookmark" row.
  @Published var isCreatingFolder = false
  @Published var newFolderName = ""

  private let contentService: VideoContentService
  private let actionsService: UserActionsService
  private let authState: AuthState
  private let errorHandler: ErrorHandler
  private let store: ContentStore
  private let defaults: UserDefaults
  private var bag = Set<AnyCancellable>()

  private static let selectionKey = "libraryLastSection"

  init(contentService: VideoContentService,
       actionsService: UserActionsService,
       authState: AuthState,
       errorHandler: ErrorHandler,
       store: ContentStore = AppContext.shared.contentStore,
       defaults: UserDefaults = .standard) {
    self.contentService = contentService
    self.actionsService = actionsService
    self.authState = authState
    self.errorHandler = errorHandler
    self.store = store
    self.defaults = defaults
    if let saved = defaults.string(forKey: Self.selectionKey),
       let section = LibrarySection(persistenceID: saved),
       // A remembered Downloads selection outlives the flag being turned off.
       section != .downloads || FeatureFlags.downloadsEnabled {
      selection = section
    }
  }

  // MARK: - Sidebar contents

  /// Every row the sidebar draws, in order: fixed sections, then folders.
  var sections: [LibrarySection] {
    LibrarySection.fixed + folders.map { .folder($0.id) }
  }

  func title(for section: LibrarySection) -> String {
    if let fixed = section.fixedTitle { return fixed }
    guard case .folder(let id) = section else { return "" }
    return folders.first { $0.id == id }?.title ?? "Bookmarks".localized
  }

  /// Item count shown beside a folder row, like the reference client. `nil` for the
  /// fixed sections — those would need an extra request each to count honestly, and a
  /// wrong number is worse than none.
  func count(for section: LibrarySection) -> String? {
    guard case .folder(let id) = section else { return nil }
    return folders.first { $0.id == id }?.count
  }

  func folder(with id: Int) -> Bookmark? {
    folders.first { $0.id == id }
  }

  // MARK: - Loading

  func load() async {
    guard authState.userState == .authorized else {
      subscribeForAuth()
      return
    }
    await refreshFolders()
  }

  func refreshFolders() async {
    do {
      // Unlike the item rows this is not cached: it is one cheap call, and we need it
      // live to know which folders even exist before drawing the sidebar.
      let fetched = try await contentService.fetchBookmarks().items
      // This screen needs the live list anyway, so hand it to the shared store — that is
      // what keeps detail pages and card menus off `/v1/bookmarks` entirely.
      BookmarkFoldersStore.shared.adopt(fetched)
      folders = fetched.recentlyUpdatedFirst()
      foldersFailed = false
      foldersError = nil
    } catch {
      Logger.app.debug("Library folders failed: \(error)")
      // Keep whatever we already knew rather than emptying the sidebar.
      foldersFailed = true
      foldersError = error
    }
    validateSelection()
  }

  /// A remembered folder can be deleted from another device between launches; fall
  /// back to the default rather than showing a section that no longer exists.
  private func validateSelection() {
    guard case .folder(let id) = selection else { return }
    guard !folders.isEmpty || !foldersFailed else { return }
    if folders.contains(where: { $0.id == id }) == false {
      selection = .watchlist
    }
  }

  func select(_ section: LibrarySection) {
    selection = section //Publishing changes from within view updates is not allowed, this will cause undefined behavior.
    defaults.set(section.persistenceID, forKey: Self.selectionKey)
  }

  // MARK: - Folder actions

  func promptNewFolder() {
    newFolderName = ""
    isCreatingFolder = true
  }

  func confirmNewFolder() {
    let title = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    isCreatingFolder = false
    newFolderName = ""
    guard !title.isEmpty else { return }
    Task {
      do {
        let id = try await actionsService.createBookmarkFolder(title: title)
        store.invalidate(family: .bookmarks)
        await refreshFolders()
        // Land the user in the folder they just made — it is empty, and that is the
        // clearest confirmation that it exists.
        select(.folder(id))
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  func deleteFolder(id: Int) {
    Task {
      do {
        try await actionsService.removeBookmarkFolder(id: id)
        if selection == .folder(id) {
          select(.watchlist)
        }
        store.invalidate(family: .bookmarks)
        await refreshFolders()
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  private func subscribeForAuth() {
    authState.$userState.filter({ $0 == .authorized }).first().sink { [weak self] _ in
      Task { await self?.load() }
    }.store(in: &bag)
  }
}
