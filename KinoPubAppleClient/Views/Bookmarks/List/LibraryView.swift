//
//  LibraryView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Combined Watchlist + History + Bookmarks for tvOS / iOS / iPad.
struct LibraryView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  @StateObject private var catalog: PersonalLibraryCatalog

  init(catalog: @autoclosure @escaping () -> PersonalLibraryCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.libraryRoutes) {
      content
        .platformNavigationTitle("Library")
        .background(Color.KinoPub.background)
        .task { await catalog.fetch() }
        .navigationDestination(for: BookmarksRoutes.self) { route in
          switch route {
          case .details(let item):
            detailsView(for: item.id, knownItem: item)
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
        .refreshable { await catalog.refresh() }
#endif
    }
    .navigationStackActive(for: .library, selected: navigationState.selectedTab)
  }

  @ViewBuilder
  private var content: some View {
    if catalog.rows.isEmpty && !catalog.isLoaded {
      LoadingIndicatorView()
    } else if catalog.rows.isEmpty {
      Text("No Results".localized)
        .foregroundStyle(Color.KinoPub.subtitle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      MediaRowsView(
        rows: catalog.rows,
        navigationLinkProvider: { card in BookmarksRoutes.detailsById(card.itemID) }
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
}
