//
//  ShortcutItemsView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// One Home catalog shelf ("Hot Movies", "Fresh Series", …) opened as its own full,
/// paginated grid — the row header's "see all". Reuses `MediaCatalog` pinned to one
/// shortcut + content type, so paging, retry and context menus come for free. No sort
/// control: the shelf already stands for one specific shortcut, and a picker would make
/// the pushed page's title a lie.
///
/// iOS/macOS only. A tvOS row header never shows a chevron (see `MediaPosterShelf`), so
/// this is never pushed there.
struct ShortcutItemsView: View {
  private let title: String

  @EnvironmentObject var navigationState: NavigationState
  @Environment(ErrorHandler.self) var errorHandler
  @Environment(\.openURL) private var openURL
  @StateObject private var catalog: MediaCatalog
  @StateObject private var cardMenu = MediaCardMenuCoordinator()

  init(title: String, catalog: @autoclosure @escaping () -> MediaCatalog) {
    self.title = title
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    content
      .platformNavigationTitle(title)
      .background(Color.KinoPub.background)
      .task {
        cardMenu.bind(errorHandler: errorHandler)
        await catalog.fetchItems()
      }
      .task { await cardMenu.refreshFolders() }
      .mediaCardNewFolderAlert(cardMenu)
      .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  private var content: some View {
    if catalog.items.isEmpty && catalog.isLoading {
      LoadingIndicatorView()
    } else if catalog.items.isEmpty && catalog.loadFailed {
      UnavailableView(title: "Couldn't Load",
                      systemImage: "wifi.exclamationmark",
                      message: catalog.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
                      retryTitle: "Try Again",
                      onRetry: {
        catalog.refresh()
      })
    } else if catalog.items.isEmpty {
      UnavailableView(title: "No Results", systemImage: "rectangle.stack")
    } else {
      grid
    }
  }

  private var grid: some View {
    ContentItemsListView(
      items: $catalog.items,
      onLoadMoreContent: { item in
        catalog.loadMoreContent(after: item)
      },
      navigationLinkProvider: { item in
        CatalogRoutesLinkProvider().link(for: item)
      },
      contextMenuProvider: { item in
        MediaCardContextMenus.entries(
          for: item,
          menu: cardMenu,
          pushRoute: { navigationState.push($0) },
          openURL: { openURL($0) }
        )
      },
      paginationError: catalog.paginationFailed,
      onRetryPagination: {
        catalog.retryPagination()
      }
    )
  }

  static func make(shortcut: MediaShortcut,
                   contentType: MediaType,
                   title: String,
                   context: AppContextProtocol,
                   authState: AuthState,
                   errorHandler: ErrorHandler) -> ShortcutItemsView {
    ShortcutItemsView(
      title: title,
      catalog: MediaCatalog(itemsService: context.contentService,
                            authState: authState,
                            errorHandler: errorHandler,
                            contentType: contentType,
                            shortcut: shortcut))
  }
}
