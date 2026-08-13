//
//  BookmarksView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

struct BookmarksView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var authState: AuthState
  @Environment(ErrorHandler.self) var errorHandler
  @Environment(\.appContext) var appContext
  @Environment(\.openURL) private var openURL
  @StateObject private var catalog: BookmarksCatalog
  @StateObject private var cardMenu = MediaCardMenuCoordinator()
  
  init(catalog: @autoclosure @escaping () -> BookmarksCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var body: some View {
    @Bindable var errorHandler = errorHandler
    RouteStack(tab: .bookmarks) {
      bookmarksRows
        .platformNavigationTitle("Bookmarks")
        .background(Color.KinoPub.background)
        .task {
          cardMenu.bind(errorHandler: errorHandler)
          await catalog.fetchItems()
        }
        .task { await cardMenu.refreshFolders() }
        .mediaCardNewFolderAlert(cardMenu)
        .handleError(state: $errorHandler.state)
    }
  }
  

  /// One row per folder, titles leading to the folder's own screen — the same shape as
  /// Home, so Saved does not make you open a folder before seeing anything.
  @ViewBuilder
  var bookmarksRows: some View {
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
      UnavailableView(title: "No Bookmarks", systemImage: "bookmark")
    } else {
      rows
    }
  }

  private var rows: some View {
    MediaRowsView(
      rows: catalog.rows,
      navigationLinkProvider: { card in
        BookmarksRoutes.detailsById(card.id)
      },
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

struct BookmarksView_Previews: PreviewProvider {
  static var previews: some View {
    BookmarksView(catalog: BookmarksCatalog(itemsService: VideoContentServiceMock(),
                                            authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()),
                                            errorHandler: ErrorHandler()))
  }
}
