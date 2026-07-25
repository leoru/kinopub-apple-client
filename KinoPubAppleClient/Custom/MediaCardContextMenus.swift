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
//      title: "Hide".localized,
      title: "Remove from Recently Watched",
         systemImage: "trash",

//      systemImage: "minus.circle",
//      systemImage: "eye.slash",
      handler: onHide
    ))

    if card.canToggleWatched {
      items.append(MediaCardContextAction(
        id: "toggle-watched",
        title: (card.isWatched ? "Mark as New" : "Mark as Watched").localized,
        systemImage: card.isWatched ? "eye" : "checkmark",
        handler: onToggleWatched
      ))
    }

    if card.isInHistory, let onBrowseHistory {
      items.append(MediaCardContextAction(
        id: "browse-history",
        title: "Browse Recently Watched".localized,
        
//        systemImage: "clock",
        systemImage: "rectangle.grid.3x2",
        handler: onBrowseHistory
      ))
    }

    if card.isInWatchlist, let onBrowseWatchlist {
      items.append(MediaCardContextAction(
        id: "browse-watchlist",
        title: "Browse My Watchlist".localized,
        systemImage: "rectangle.grid.3x2",
        handler: onBrowseWatchlist
      ))
    }

    return items
  }
}
