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
  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext
  @Environment(\.openURL) private var openURL

  @StateObject private var catalog: HomeCatalog
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  init(catalog: @autoclosure @escaping () -> HomeCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    RouteStack(tab: .home, zoom: true) {
      // No page-level material and no `backgroundExtensionEffect` on any platform.
      //
      // That modifier duplicates the view into *mirrored, blurred copies* laid into
      // whatever safe area is free. It exists for the detail column of a
      // `NavigationSplitView`, so artwork can bleed under an overlaying sidebar or
      // inspector. This app has no split view at all, and our sidebars are meant to
      // displace content, not float over it — so there is nothing for the copies to
      // sit behind. What it produced instead was mirrored rows smeared into the
      // navigation and tab bars, and, on a failed or empty load, a mirrored copy of
      // the error placeholder. The native Apple TV app does not do this.
      //
      // The navigation bar is likewise left to the system: on 26 it is already
      // Liquid Glass with the scroll-edge effect.
      rowsView
        .platformNavigationTitle("Home")
#if os(macOS)
        .macToolbarSearch()
#endif
        .handleError(state: $errorHandler.state)
        .task {
          cardMenu.bind(errorHandler: errorHandler)
          await catalog.fetch()
        }
        .onAppear {
          catalog.repaintFromLocalProgress()
        }
        .task {
          await cardMenu.refreshFolders()
        }
        .mediaCardNewFolderAlert(cardMenu)
    }
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

  @ViewBuilder
  private var rows: some View {
    MediaRowsView(
      rows: catalog.rows,
      // Gated by `FeatureFlags.homeBannerEnabled`. When off, HomeCatalog also
      // skips sampling so wide-poster artwork is never requested.
      bannerCards: FeatureFlags.homeBannerEnabled ? catalog.bannerCards : [],
      navigationLinkProvider: { card in
        if card.opensCollection {
          Route.collection(CollectionMediaCard.routeCollection(from: card))
        } else {
          Route.detailsById(card.id)
        }
      },
      onPlay: { card in
        cardMenu.play(card) { navigationState.push($0) }
      },
      // Horizontal paging: the shelf reports its last card, the catalog decides whether
      // a next page exists. Continue Watching declines inside `loadMore`.
      onLoadMore: { row, _ in
        catalog.loadMore(rowID: row.id)
      },
      paginationProvider: { row in
        catalog.paginationState(rowID: row.id, loadedCount: row.cards.count)
      },
      onRetryPagination: { row in
        catalog.retryPagination(rowID: row.id)
      },
      contextMenuProvider: { card, surface in
        guard !card.opensCollection else { return [] }
        return menuEntries(for: card, surface: surface, isContinueWatching: card.isLandscape)
      }
    )
  }

  private func menuEntries(for card: MediaCard,
                           surface: MediaCardContextSurface,
                           isContinueWatching: Bool) -> [MediaCardContextEntry] {
    let containing = cardMenu.containingFolders(for: card)
    let folders = cardMenu.folders.map {
      MediaCardContextMenus.BookmarkFolderOption(
        id: $0.id,
        title: $0.title,
        isContaining: containing.contains($0.id)
      )
    }

    let onToggleWatched: (() -> Void)? = {
      if isContinueWatching {
        return card.canToggleWatched ? { catalog.toggleWatched(card) } : nil
      }
      return card.isSeries ? nil : {
        cardMenu.toggleWatched(card, removeFromContinueWatching: false)
      }
    }()

    return MediaCardContextMenus.entries(
      for: card,
      surface: surface,
      bookmarkFolders: folders,
      onPlay: { cardMenu.play(card) { navigationState.push($0) } },
      onGoToTitle: { navigationState.push(.detailsById(card.itemID)) },
      onToggleWatchlist: card.isSeries ? { cardMenu.toggleWatchlist(card) } : nil,
      onToggleBookmarkFolder: { folderID in
        guard let folder = cardMenu.folders.first(where: { $0.id == folderID }) else { return }
        cardMenu.toggleBookmark(itemID: card.itemID,
                                folder: folder,
                                serverHint: Set(card.bookmarkFolderIDs))
      },
      onCreateBookmarkFolder: { cardMenu.promptNewFolder(for: card.itemID) },
      onToggleWatched: onToggleWatched,
      onHide: isContinueWatching ? { catalog.hide(card) } : nil,
      onOpenImageURL: { openURL($0) }
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
