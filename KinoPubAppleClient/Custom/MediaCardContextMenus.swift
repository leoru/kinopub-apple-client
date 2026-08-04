//
//  MediaCardContextMenus.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend
import KinoPubUI

/// Single source of card context-menu items (ids, titles, icons, grouping).
/// Call sites pass handlers / folder state — missing pieces omit those rows.
enum MediaCardContextMenus {

  struct BookmarkFolderOption: Identifiable {
    let id: Int
    let title: String
    let isContaining: Bool
  }

  /// Full Home / Library / banner menu driven by optional handlers.
  static func entries(
    for card: MediaCard,
    surface: MediaCardContextSurface = .shelf,
    bookmarkFolders: [BookmarkFolderOption] = [],
    onPlay: (() -> Void)? = nil,
    onGoToTitle: (() -> Void)? = nil,
    onToggleWatchlist: (() -> Void)? = nil,
    onToggleBookmarkFolder: ((Int) -> Void)? = nil,
    onCreateBookmarkFolder: (() -> Void)? = nil,
    onToggleWatched: (() -> Void)? = nil,
    onHide: (() -> Void)? = nil,
    onOpenImageURL: ((URL) -> Void)? = nil,
    /// DEBUG menu rows — when empty, falls back to the card's painted artwork URL.
    debugImageURLs: [URL] = []
  ) -> [MediaCardContextEntry] {
    // TODO(downloads): when `FeatureFlags.downloadsEnabled` ships, add Download here.
    var entries: [MediaCardContextEntry] = []
    var needsDivider = false

    func appendDivider() {
      if needsDivider {
        entries.append(.divider(id: "divider-\(entries.count)"))
      }
      needsDivider = false
    }

    func markGroup() {
      needsDivider = true
    }

    // MARK: Playback
    if let onPlay {
      appendDivider()
      entries.append(.action(MediaCardContextAction(
        id: "play",
        title: "Play".localized,
        systemImage: "play.fill",
        handler: onPlay
      )))
      markGroup()
    }

    // MARK: Navigation
    if let onGoToTitle {
      appendDivider()
      entries.append(.action(MediaCardContextAction(
        id: "go-to-title",
        title: (card.isSeries ? "Go to Show" : "Go to Movie").localized,
        systemImage: "info.circle",
        handler: onGoToTitle
      )))
      markGroup()
    }

    // MARK: Library
    let showBookmarks = onToggleBookmarkFolder != nil || onCreateBookmarkFolder != nil
    let hasLibrary = onToggleWatchlist != nil || showBookmarks
    if hasLibrary {
      appendDivider()
      if let onToggleWatchlist {
        entries.append(.action(MediaCardContextAction(
          id: "toggle-watchlist",
          title: (card.isInWatchlist ? "Remove from Watchlist" : "Add to Watchlist").localized,
          systemImage: card.isInWatchlist ? "text.badge.minus" : "text.badge.plus",
          handler: onToggleWatchlist
        )))
      }
      if showBookmarks {
        let children: [MediaCardContextAction]
        if let onToggleBookmarkFolder {
          children = bookmarkFolders.map { folder in
            MediaCardContextAction(
              id: "bookmark-folder-\(folder.id)",
              title: folder.title,
              systemImage: "folder",
              isSelection: true,
              isOn: folder.isContaining,
              handler: { onToggleBookmarkFolder(folder.id) }
            )
          }
        } else {
          children = []
        }
        let footer: [MediaCardContextAction]
        if let onCreateBookmarkFolder {
          footer = [
            MediaCardContextAction(
              id: "new-bookmark-folder",
              title: "New Folder".localized,
              systemImage: "folder.badge.plus",
              handler: onCreateBookmarkFolder
            )
          ]
        } else {
          footer = []
        }
        entries.append(.submenu(
          id: "bookmarks",
          title: "Add to Bookmarks".localized,
          systemImage: "bookmark",
          children: children,
          footer: footer
        ))
      }
      markGroup()
    }

    // MARK: Watched
    if let onToggleWatched {
      appendDivider()
      entries.append(.action(MediaCardContextAction(
        id: "toggle-watched",
        title: (card.isWatched ? "Mark as New" : "Mark as Watched").localized,
        systemImage: card.isWatched ? "eye" : "checkmark",
        handler: onToggleWatched
      )))
      markGroup()
    }

    // MARK: Destructive / CW
    if let onHide {
      appendDivider()
      entries.append(.action(MediaCardContextAction(
        id: "hide",
        title: "Remove from Recently Watched",
        systemImage: "trash",
        role: .destructive,
        handler: onHide
      )))
      markGroup()
    }

    // MARK: Debug
#if DEBUG
    var debugURLs = debugImageURLs
    if debugURLs.isEmpty,
       let raw = artworkURL(for: card, surface: surface),
       let url = URL(string: raw) {
      debugURLs = [url]
    }
    if let onOpenImageURL, !debugURLs.isEmpty {
      appendDivider()
      for (index, url) in debugURLs.enumerated() {
        entries.append(.action(MediaCardContextAction(
          id: "debug-image-url-\(index)",
          title: url.absoluteString,
          systemImage: "link",
          handler: { onOpenImageURL(url) }
        )))
      }
    }
#else
    _ = debugImageURLs
    _ = onOpenImageURL
    _ = surface
#endif

    return entries
  }

  /// URL of the artwork the surface actually paints (shelf lockup vs banner backdrop).
  static func artworkURL(for card: MediaCard, surface: MediaCardContextSurface) -> String? {
    let raw: String
    switch surface {
    case .shelf:
      if let landscape = card.landscapeImageURL, !landscape.isEmpty {
        raw = landscape
      } else {
        raw = card.posterURL
      }
    case .banner:
      if let backdrop = card.backdropURL, !backdrop.isEmpty {
        raw = backdrop
      } else {
        raw = card.posterURL
      }
    }
    return raw.isEmpty ? nil : raw
  }

  /// Builds entries for a card using the shared coordinator + navigation hooks.
  @MainActor
  static func entries(
    for card: MediaCard,
    surface: MediaCardContextSurface,
    menu: MediaCardMenuCoordinator,
    pushRoute: @escaping (Route) -> Void,
    openURL: @escaping (URL) -> Void,
    isContinueWatchingStyle: Bool = false,
    includePlay: Bool = true,
    includeGoToTitle: Bool = true
  ) -> [MediaCardContextEntry] {
    menu.prefetchMembership(for: card.itemID)
    let containing = menu.membershipByItemID[card.itemID] ?? []
    let folderOptions = menu.folders.map {
      BookmarkFolderOption(id: $0.id, title: $0.title, isContaining: containing.contains($0.id))
    }

    let canMarkWatched: Bool = {
      if isContinueWatchingStyle { return card.canToggleWatched || !card.isSeries }
      return !card.isSeries
    }()

    return entries(
      for: card,
      surface: surface,
      bookmarkFolders: folderOptions,
      onPlay: includePlay ? { menu.play(card, push: pushRoute) } : nil,
      onGoToTitle: includeGoToTitle ? { pushRoute(.detailsById(card.itemID)) } : nil,
      onToggleWatchlist: card.isSeries ? { menu.toggleWatchlist(card) } : nil,
      onToggleBookmarkFolder: { folderID in
        guard let folder = menu.folders.first(where: { $0.id == folderID }) else { return }
        menu.toggleBookmark(itemID: card.itemID, folder: folder)
      },
      onCreateBookmarkFolder: { menu.promptNewFolder(for: card.itemID) },
      onToggleWatched: canMarkWatched
        ? { menu.toggleWatched(card, removeFromContinueWatching: isContinueWatchingStyle) }
        : nil,
      onHide: isContinueWatchingStyle
        ? { menu.hideFromContinueWatching(card) }
        : nil,
      onOpenImageURL: openURL
    )
  }
}
