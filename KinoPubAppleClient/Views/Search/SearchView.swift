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
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  @StateObject private var catalog: LibraryCatalog

  init(catalog: @autoclosure @escaping () -> LibraryCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  /// Enough empty posters to sketch a couple of rows before the page arrives.
  private static let placeholderCount = 12

  var body: some View {
    NavigationStack(path: $navigationState.searchRoutes) {
      GeometryReader { geometryProxy in
        ContentItemsListView(
          width: geometryProxy.size.width,
          items: $catalog.items,
          onLoadMoreContent: { item in
            catalog.loadMoreContent(after: item)
          },
          onRefresh: {
            await catalog.refresh()
          },
          navigationLinkProvider: { item in
            SearchRoutesLinkProvider().link(for: item)
          },
          placeholderCount: showsPlaceholders ? Self.placeholderCount : 0,
          emptyMessage: showsEmptyMessage ? "No resuts" : nil
        ) {
          // Filters scroll away with the grid — pinning them above a remnant
          // GeometryReader was eating half the screen and delaying `.searchable`.
          if !catalog.isSearching {
            LibraryFiltersBar(catalog: catalog)
          }
        }
      }
      .searchable(text: $catalog.query, placement: .automatic)
      .platformNavigationTitle("Search")
      .background(Color.KinoPub.background)
      .navigationDestination(for: SearchRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              knownItem: item,
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
        case .person(let person):
          PersonItemsView.make(person: person,
                               linkProvider: SearchRoutesLinkProvider(),
                               context: appContext,
                               authState: authState,
                               errorHandler: errorHandler)
        }
      }
      .handleError(state: $errorHandler.state)
      .task {
        await catalog.load()
      }
    }
  }

  private var showsPlaceholders: Bool {
    catalog.items.isEmpty && catalog.isLoading
  }

  private var showsEmptyMessage: Bool {
    catalog.items.isEmpty && catalog.isSearching && !catalog.isLoading
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
