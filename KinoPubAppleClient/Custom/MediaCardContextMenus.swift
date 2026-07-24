//
//  MediaCardContextMenus.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubUI

/// Shared long-press actions for continue-watching and episode cards.
enum MediaCardContextMenus {

  static func actions(for card: MediaCard,
                      includeGoToTitle: Bool,
                      onHide: @escaping () -> Void,
                      onToggleWatched: @escaping () -> Void,
                      onGoToTitle: @escaping () -> Void,
                      onBrowseHistory: (() -> Void)? = nil,
                      onBrowseWatchlist: (() -> Void)? = nil) -> [MediaCardContextAction] {
    var items: [MediaCardContextAction] = []

    if includeGoToTitle {
      items.append(MediaCardContextAction(
        id: "go-to-title",
        title: (card.isSeries ? "Go to Show" : "Go to Movie").localized,
        systemImage: "info.circle",
        handler: onGoToTitle
      ))
    }

    items.append(MediaCardContextAction(
      id: "hide",
      title: "Hide from Here".localized,
      systemImage: "eye.slash",
      handler: onHide
    ))

    if card.canToggleWatched {
      items.append(MediaCardContextAction(
        id: "toggle-watched",
        title: (card.isWatched ? "Mark as Unwatched" : "Mark as Watched").localized,
        systemImage: card.isWatched ? "eye" : "checkmark",
        handler: onToggleWatched
      ))
    }

    if card.isInHistory, let onBrowseHistory {
      items.append(MediaCardContextAction(
        id: "browse-history",
        title: "Browse History".localized,
        systemImage: "clock",
        handler: onBrowseHistory
      ))
    }

    if card.isInWatchlist, let onBrowseWatchlist {
      items.append(MediaCardContextAction(
        id: "browse-watchlist",
        title: "Browse Watchlist".localized,
        systemImage: "bookmark",
        handler: onBrowseWatchlist
      ))
    }

    return items
  }
}
