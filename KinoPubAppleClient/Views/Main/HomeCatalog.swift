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
    async let serialsTask = try? itemsService.fetchWatchingSerials().items

    let serials = await serialsTask ?? []
    let movies = await moviesTask ?? []

    // Serials with new episodes are the reason to open the app, so they lead.
    let cards = (serials + movies).map(Self.card(for:))
    guard !cards.isEmpty else { return nil }

    return MediaRow(id: Self.continueWatchingRowID,
                    title: "Continue Watching".localized,
                    cards: cards)
  }

  private static func card(for item: WatchingItem) -> MediaCard {
    MediaCard(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              progress: item.progress,
              badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil)
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
