//
//  WatchlistView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubLogging
import OSLog

/// Serials the user is following for new episodes — its own sidebar tab, not a
/// row on Bookmarks.
struct WatchlistView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  @State private var cards: [MediaCard] = []
  @State private var isLoaded = false

  var body: some View {
    NavigationStack(path: $navigationState.watchlistRoutes) {
      content
        .platformNavigationTitle("Watchlist")
        .background(Color.KinoPub.background)
        .task { await load() }
        .navigationDestination(for: BookmarksRoutes.self) { route in
          switch route {
          case .details(let item):
            detailsView(for: item.id, knownItem: item)
          case .detailsById(let id):
            detailsView(for: id)
          case .bookmark:
            EmptyView()
          case .player(let item):
            PlayerView(manager: PlayerManager(playItem: item,
                                              watchMode: .media,
                                              downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                              actionsService: appContext.actionsService))
          case .trailerPlayer(let item):
            PlayerView(manager: PlayerManager(playItem: item,
                                              watchMode: .trailer,
                                              downloadedFilesDatabase: appContext.downloadedFilesDatabase,
                                              actionsService: appContext.actionsService))
          case .seasons(let seasons):
            SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: BookmarksRoutesLinkProvider()))
          case .season(let season):
            SeasonView(model: SeasonModel(season: season, linkProvider: BookmarksRoutesLinkProvider()))
          case .person(let person):
            PersonItemsView.make(person: person,
                                 linkProvider: BookmarksRoutesLinkProvider(),
                                 context: appContext,
                                 authState: authState,
                                 errorHandler: errorHandler)
          }
        }
        .handleError(state: $errorHandler.state)
#if !os(tvOS)
        .refreshable { await load(force: true) }
#endif
    }
    .navigationStackActive(for: .watchlist, selected: navigationState.selectedTab)
  }

  @ViewBuilder
  private var content: some View {
    if cards.isEmpty && !isLoaded {
      LoadingIndicatorView()
    } else if cards.isEmpty {
      Text("No Results".localized)
        .foregroundStyle(Color.KinoPub.subtitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      MediaRowsView(
        rows: [MediaRow(id: "watchlist", title: "Watchlist".localized, cards: cards)],
        navigationLinkProvider: { card in BookmarksRoutes.detailsById(card.id) },
        showsFeaturedPreview: false
      )
    }
  }

  private func detailsView(for id: Int, knownItem: MediaItem? = nil) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        knownItem: knownItem,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: BookmarksRoutesLinkProvider(),
                                        errorHandler: errorHandler))
  }

  private func load(force: Bool = false) async {
    if force {
      cards = []
      isLoaded = false
    }
    do {
      let items = try await appContext.contentService.fetchWatchingSerials(subscribedOnly: true).items
      cards = items.map(Self.card(for:))
      isLoaded = true
    } catch {
      Logger.app.error("Failed to load watchlist: \(error)")
      errorHandler.setError(error)
      isLoaded = true
    }
  }

  private static func card(for item: WatchingItem) -> MediaCard {
    MediaCard(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              badge: item.hasNewEpisodes ? "+\(item.new ?? 0)" : nil,
              backdropURL: item.posters.wideURL ?? item.posters.big)
  }
}
