//
//  SearchView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Search, sorting and filtering all live here so the Main tab can be a pure
/// browse surface (rows of artwork) the way tvOS apps present a home screen.
struct SearchView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext

  @StateObject private var catalog: LibraryCatalog

  init(catalog: @autoclosure @escaping () -> LibraryCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.searchRoutes) {
      VStack(spacing: 0) {
        // Sorting and filtering apply to the catalog listing, not to a search.
        if !catalog.isSearching {
          LibraryFiltersBar(catalog: catalog)
        }

        if catalog.items.isEmpty && catalog.isSearching {
          emptyView
        } else {
          catalogView
        }
      }
      .searchable(text: $catalog.query, placement: .automatic)
      .platformNavigationTitle("Search")
      .background(Color.KinoPub.background)
      .navigationDestination(for: SearchRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: SearchRoutesLinkProvider(),
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
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: SearchRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: SearchRoutesLinkProvider()))
        }
      }
      .handleError(state: $errorHandler.state)
      .task {
        await catalog.load()
      }
    }
  }

  var catalogView: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width, items: $catalog.items, onLoadMoreContent: { item in
        catalog.loadMoreContent(after: item)
      }, onRefresh: {
        await catalog.refresh()
      }, navigationLinkProvider: { item in
        SearchRoutesLinkProvider().link(for: item)
      })
    }
  }

  var emptyView: some View {
    Text("No resuts")
      .foregroundStyle(Color.KinoPub.text)
      .font(Font.KinoPub.subheader)
  }
}

struct SearchView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()

  static var previews: some View {
    SearchView(catalog: LibraryCatalog(itemsService: VideoContentServiceMock(),
                                       authState: AuthState(authService: AuthorizationServiceMock(),
                                                            accessTokenService: AccessTokenServiceMock()),
                                       errorHandler: ErrorHandler()))
    .environmentObject(navState)
  }
}
