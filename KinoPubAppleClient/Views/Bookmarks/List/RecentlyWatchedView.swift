//
//  RecentlyWatchedView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Sidebar tab wrapper around `HistoryView` with its own stack so links do not
/// steal Home's `mainRoutes` path.
struct RecentlyWatchedView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  var body: some View {
    NavigationStack(path: $navigationState.recentlyWatchedRoutes) {
      HistoryView()
        .navigationDestination(for: MainRoutes.self) { route in
          switch route {
          case .details(let item):
            detailsView(for: item.id, knownItem: item)
          case .detailsById(let id):
            detailsView(for: id)
          case .history:
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
            SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: MainRoutesLinkProvider()))
          case .season(let season):
            SeasonView(model: SeasonModel(season: season, linkProvider: MainRoutesLinkProvider()))
          case .person(let person):
            PersonItemsView.make(person: person,
                                 linkProvider: MainRoutesLinkProvider(),
                                 context: appContext,
                                 authState: authState,
                                 errorHandler: errorHandler)
          }
        }
    }
    .navigationStackActive(for: .recentlyWatched, selected: navigationState.selectedTab)
  }

  private func detailsView(for id: Int, knownItem: MediaItem? = nil) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        knownItem: knownItem,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: MainRoutesLinkProvider(),
                                        errorHandler: errorHandler))
  }
}
