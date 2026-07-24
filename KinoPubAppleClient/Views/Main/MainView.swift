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
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  @StateObject private var catalog: HomeCatalog

  init(catalog: @autoclosure @escaping () -> HomeCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.mainRoutes) {
      rowsView
        .platformNavigationTitle("Main")

#if os(tvOS)
        .background(.ultraThickMaterial)
#else
        .background(Color.KinoPub.background)
#endif

        .navigationDestination(for: MainRoutes.self) { route in
          switch route {
          case .details(let item):
            detailsView(for: item.id, knownItem: item)
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
          case .person(let person):
            PersonItemsView.make(person: person,
                                 linkProvider: MainRoutesLinkProvider(),
                                 context: appContext,
                                 authState: authState,
                                 errorHandler: errorHandler)
          }
        }
        .handleError(state: $errorHandler.state)
        .task {
          await catalog.fetch()
        }
    }
  }

  private func detailsView(for id: Int, knownItem: MediaItem? = nil) -> some View {
    MediaItemView(model: MediaItemModel(mediaItemId: id,
                                        knownItem: knownItem,
                                        itemsService: appContext.contentService,
                                        downloadManager: appContext.downloadManager,
                                        linkProvider: MainRoutesLinkProvider(),
                                        errorHandler: errorHandler))
  }

  /// Nothing on screen until the rows arrive, then a spinner if the wait drags on —
  /// the Apple TV app's own loading behaviour.
  @ViewBuilder
  var rowsView: some View {
    if catalog.rows.isEmpty && !catalog.isLoaded {
      LoadingIndicatorView()
    } else {
      rows
    }
  }

  private var rows: some View {
    MediaRowsView(rows: catalog.rows, navigationLinkProvider: { card in
      MainRoutes.detailsById(card.id)
    },
    // The focused-card blur hero is off on Home for now — too heavy on device, and it hid
    // the tab bar. Plain rows until it returns as a lighter top slider.
    showsFeaturedPreview: false)
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
