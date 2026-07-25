//
//  BookmarkFolderTabView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// One bookmark folder as a sidebar tab — own stack so folder switches stay isolated.
struct BookmarkFolderTabView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  let bookmark: Bookmark
  @State private var path: [BookmarksRoutes] = []

  var body: some View {
    NavigationStack(path: $path) {
      BookmarkView(model: BookmarkModel(bookmark: bookmark,
                                        itemsService: appContext.contentService,
                                        errorHandler: errorHandler))
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
    }
    .navigationStackActive(for: .bookmark(bookmark.id), selected: navigationState.selectedTab)
    .id(bookmark.id)
  }

  private func detailsView(for id: Int, knownItem: MediaItem? = nil) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        knownItem: knownItem,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: BookmarksRoutesLinkProvider(),
                                        errorHandler: errorHandler))
  }
}
