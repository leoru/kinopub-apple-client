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

  @StateObject private var catalog: HomeCatalog

  init(catalog: @autoclosure @escaping () -> HomeCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.mainRoutes) {
      rowsView
        .platformNavigationTitle("Main")
        .background(Color.KinoPub.background)
        .navigationDestination(for: MainRoutes.self) { route in
          switch route {
          case .details(let item):
            detailsView(for: item.id)
          case .detailsById(let id):
            detailsView(for: id)
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
          await catalog.fetch()
        }
    }
  }

  private func detailsView(for id: Int) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: MainRoutesLinkProvider(),
                                        errorHandler: errorHandler))
  }

  var rowsView: some View {
    MediaRowsView(rows: catalog.rows, navigationLinkProvider: { card in
      MainRoutes.detailsById(card.id)
    })
#if !os(tvOS)
    .refreshable {
      await catalog.refresh()
    }
#endif
  }
}

struct MainView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()

  static var previews: some View {
    MainView(catalog: HomeCatalog(itemsService: VideoContentServiceMock(),
                                  authState: AuthState(authService: AuthorizationServiceMock(),
                                                       accessTokenService: AccessTokenServiceMock()),
                                  errorHandler: ErrorHandler()))
      .environmentObject(navState)
  }
}
