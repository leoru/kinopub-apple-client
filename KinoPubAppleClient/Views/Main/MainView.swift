//
//  MainView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubUI
import KinoPubBackend

struct MainView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  
  @StateObject private var catalog: MediaCatalog

  init(catalog: @autoclosure @escaping () -> MediaCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.mainRoutes) {
      catalogView
      .navigationTitle(catalog.title.localized)
      .background(Color.KinoPub.background)
      .navigationDestination(for: MainRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: MainRoutesLinkProvider(),
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
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: MainRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: MainRoutesLinkProvider()))
        }
      }
      .handleError(state: $errorHandler.state)
      .task {
        await catalog.fetchItems()
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
        MainRoutesLinkProvider().link(for: item)
      })
    }
  }
  
}

struct MainView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()
  
  static var previews: some View {
    MainView(catalog: MediaCatalog(itemsService: VideoContentServiceMock(), authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()), errorHandler: ErrorHandler()))
      .environmentObject(navState)
  }
}
