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
  @Environment(\.openURL) private var openURL
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  @StateObject private var catalog: PersonalLibraryCatalog

  init(catalog: @autoclosure @escaping () -> PersonalLibraryCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    NavigationStack(path: $navigationState.libraryRoutes) {
      content
        .platformNavigationTitle("Library")
        .background(Color.KinoPub.background)
        .task {
          cardMenu.bind(errorHandler: errorHandler)
          await catalog.fetch()
        }
        .task { await cardMenu.refreshFolders() }
        .mediaCardNewFolderAlert(cardMenu)
        .navigationDestination(for: Route.self) { route in
          RouteDestination(route: route, linkProvider: AppRoutesLinkProvider())
        }
        .handleError(state: $errorHandler.state)
    }
    .navigationStackActive(for: .library, selected: navigationState.selectedTab)
  }

  @ViewBuilder
  private var content: some View {
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
    } else if catalog.rows.isEmpty {
      UnavailableView(title: "No Results", systemImage: "bookmark")
    } else {
      MediaRowsView(
        rows: catalog.rows,
        navigationLinkProvider: { card in BookmarksRoutes.detailsById(card.itemID) },
        contextMenuProvider: { card, surface in
          MediaCardContextMenus.entries(
            for: card,
            surface: surface,
            menu: cardMenu,
            pushRoute: { navigationState.push($0) },
            openURL: { openURL($0) }
          )
        }
      )
    }
  }

}
