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
  @Namespace private var zoomNamespace

  @StateObject private var catalog: HomeCatalog

  init(catalog: @autoclosure @escaping () -> HomeCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.mainRoutes) {
      rowsView
        .platformNavigationTitle("Home")
#if os(iOS) || os(tvOS)
        .background(.ultraThickMaterial)
        .backgroundExtensionEffect()
#endif
#if os(iOS)
        .containerBackground(.ultraThickMaterial, for: .navigation)
#endif
        .navigationDestination(for: Route.self) { route in
          RouteDestination(route: route,
                           linkProvider: AppRoutesLinkProvider(),
                           transitionNamespace: zoomNamespace)
        }
        .handleError(state: $errorHandler.state)
        .task {
          await catalog.fetch()
        }
    }
    .environment(\.zoomTransitionNamespace, zoomNamespace)
    .navigationStackActive(for: .home, selected: navigationState.selectedTab)
  }

  /// Nothing on screen until the rows arrive, then a spinner if the wait drags on —
  /// the Apple TV app's own loading behaviour. A failed cold start (nothing cached,
  /// every shelf errored) gets a retry state instead of a blank page.
  @ViewBuilder
  var rowsView: some View {
    if catalog.rows.isEmpty && !catalog.isLoaded {
      LoadingIndicatorView()
    } else if catalog.rows.isEmpty && catalog.loadFailed {
      UnavailableView(title: "Couldn't Load",
                      systemImage: "wifi.exclamationmark",
                      message: catalog.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                      retryTitle: "Try Again",
                      onRetry: {
        Task { await catalog.refresh() }
      })
    } else {
      rows
    }
  }

  private var rows: some View {
    MediaRowsView(
      rows: catalog.rows,
      bannerCards: catalog.bannerCards,
      navigationLinkProvider: { card in
        Route.detailsById(card.id)
      },
      contextMenuProvider: { card in
        // Continue Watching is the only home row whose long-press can hide or mark a
        // specific resume point. Catalog posters stay tap-to-open.
        guard card.isLandscape else { return [] }
        return MediaCardContextMenus.actions(
          for: card,
          includeGoToTitle: true,
          onHide: { catalog.hide(card) },
          onToggleWatched: { catalog.toggleWatched(card) },
          onGoToTitle: { navigationState.mainRoutes.append(.detailsById(card.itemID)) },
          onBrowseHistory: { navigationState.mainRoutes.append(.history) },
          onBrowseWatchlist: {
#if os(macOS)
            navigationState.selectedTab = .watchlist
#else
            navigationState.selectedTab = .library
#endif
          }
        )
      }
    )
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
