//
//  BookmarksView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubUI

struct BookmarksView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var catalog: BookmarksCatalog
  
  init(catalog: @autoclosure @escaping () -> BookmarksCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var body: some View {
    NavigationStack(path: $navigationState.bookmarksRoutes) {
      bookmarksRows
        .platformNavigationTitle("Bookmarks")
        .background(Color.KinoPub.background)
        .task {
          await catalog.fetchItems()
        }
        .navigationDestination(for: BookmarksRoutes.self) { route in
          switch route {
          case .details(let item):
            detailsView(for: item.id)
          case .detailsById(let id):
            detailsView(for: id)
          case .bookmark(let bookmark):
            BookmarkView(model: BookmarkModel(bookmark: bookmark,
                                              itemsService: appContext.contentService,
                                              errorHandler: errorHandler))
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
          }
        }
        .handleError(state: $errorHandler.state)
    }
  }
  
  private func detailsView(for id: Int) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: BookmarksRoutesLinkProvider(),
                                        errorHandler: errorHandler))
  }

  /// One row per folder, titles leading to the folder's own screen — the same shape as
  /// Home, so Saved does not make you open a folder before seeing anything.
  var bookmarksRows: some View {
    MediaRowsView(rows: catalog.rows, navigationLinkProvider: { card in
      BookmarksRoutes.detailsById(card.id)
    })
#if !os(tvOS)
    .refreshable {
      await catalog.refresh()
    }
#endif
  }
}

struct BookmarksView_Previews: PreviewProvider {
  static var previews: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: VideoContentServiceMock(),
                                            authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                            errorHandler: ErrorHandler()))
  }
}
