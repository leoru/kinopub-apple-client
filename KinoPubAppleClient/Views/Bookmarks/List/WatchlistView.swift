//
//  WatchlistView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubLogging
import OSLog

/// Serials the user is following for new episodes — vertical poster grid.
/// Reads through `ContentStore`, so a warm cache paints instantly and a failed
/// refresh keeps the last known list instead of blanking the tab.
struct WatchlistView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext
  @Environment(\.openURL) private var openURL
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  @State private var cards: [MediaCard] = []
  @State private var isLoaded = false
  @State private var loadFailed = false
  @State private var loadError: Error?

  var body: some View {
    NavigationStack(path: $navigationState.watchlistRoutes) {
      content
        .platformNavigationTitle("Watchlist")
        .background(Color.KinoPub.background)
        .task {
          cardMenu.bind(errorHandler: errorHandler)
          await load()
        }
        .task { await cardMenu.refreshFolders() }
        .mediaCardNewFolderAlert(cardMenu)
        .navigationDestination(for: Route.self) { route in
          RouteDestination(route: route, linkProvider: AppRoutesLinkProvider())
        }
        .handleError(state: $errorHandler.state)
    }
    .navigationStackActive(for: .watchlist, selected: navigationState.selectedTab)
  }

  @ViewBuilder
  private var content: some View {
    if cards.isEmpty && !isLoaded {
      LoadingIndicatorView()
    } else if cards.isEmpty && loadFailed {
      UnavailableView(title: "Couldn't Load",
                      systemImage: "wifi.exclamationmark",
                      message: loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                      retryTitle: "Try Again",
                      onRetry: {
        Task { await load(force: true) }
      })
    } else if cards.isEmpty {
      UnavailableView(title: "No Results", systemImage: "text.append")
    } else {
      MediaCardsListView(
        cards: cards,
        onLoadMoreContent: { _ in },
        navigationLinkProvider: { card in BookmarksRoutes.detailsById(card.id) },
        contextMenuProvider: { card in
          MediaCardContextMenus.entries(
            for: card,
            surface: .shelf,
            menu: cardMenu,
            pushRoute: { navigationState.push($0) },
            openURL: { openURL($0) }
          )
        }
      )
    }
  }

  private func load(force: Bool = false) async {
    let store = appContext.contentStore
    cards = store.cards(.watchlist)
    isLoaded = !cards.isEmpty
    loadFailed = false
    loadError = nil

    let willFetch = force || store.isStale(.watchlist)
    let service = appContext.contentService
    let fetch: @Sendable () async throws -> [MediaCard] = {
      let items = try await service.fetchWatchingSerials(subscribedOnly: true).items
      return items.map(Self.card(for:))
    }
    if force {
      await store.refresh(.watchlist, fetch: fetch)
    } else {
      await store.refreshIfStale(.watchlist, fetch: fetch)
    }

    cards = store.cards(.watchlist)
    isLoaded = true
    loadFailed = cards.isEmpty && store.lastError(.watchlist) != nil
    loadError = cards.isEmpty ? store.lastError(.watchlist) : nil
    if willFetch, !cards.isEmpty, let error = store.lastError(.watchlist) {
      errorHandler.setError(error)
    }
  }

  private nonisolated static func card(for item: WatchingItem) -> MediaCard {
    MediaCard(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
              backdropURL: item.posters.wideURL ?? item.posters.big,
              isSeries: true,
              isInWatchlist: true)
  }
}
