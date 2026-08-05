//
//  CatalogView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// A browse tab pinned to one content type — Movies or Series. Paginated grid with a
/// sort control; searching and filtering live in the Search tab.
struct CatalogView: View {
  @EnvironmentObject var navigationState: NavigationState
  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext
  @Environment(\.openURL) private var openURL

  private let title: LocalizedStringKey
  private let tab: NavigationTabs
  private let path: ReferenceWritableKeyPath<NavigationState, [CatalogRoutes]>

  @StateObject private var catalog: MediaCatalog
  @StateObject private var cardMenu = MediaCardMenuCoordinator()
  @State private var showShortCutPicker: Bool = false
  @Namespace private var zoomNamespace

  init(title: LocalizedStringKey,
       tab: NavigationTabs,
       path: ReferenceWritableKeyPath<NavigationState, [CatalogRoutes]>,
       catalog: @autoclosure @escaping () -> MediaCatalog) {
    self.title = title
    self.tab = tab
    self.path = path
    _catalog = StateObject(wrappedValue: catalog())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    NavigationStack(path: Binding(get: { navigationState[keyPath: path] },
                                  set: { navigationState[keyPath: path] = $0 })) {
      catalogView
        .platformNavigationTitle(title)
        .background(Color.KinoPub.background)
        .toolbar {
          // Not `.primaryAction` on macOS — that placement nests inside `.searchable`
          // and makes the search field look custom (sort glyph in the field).
          ToolbarItem(placement: sortToolbarPlacement) {
            Button {
              showShortCutPicker = true
            } label: {
              Label("Sort", systemImage: "arrow.up.arrow.down")
            }
          }
        }
#if os(macOS)
        .macToolbarSearch()
#endif
        .sheet(isPresented: $showShortCutPicker) {
          ShortcutSelectionView(shortcut: $catalog.shortcut, mediaType: $catalog.contentType)
        }
        .navigationDestination(for: Route.self) { route in
          RouteDestination(route: route,
                           linkProvider: AppRoutesLinkProvider(),
                           transitionNamespace: zoomNamespace)
        }
        .handleError(state: $errorHandler.state)
        .task {
          cardMenu.bind(errorHandler: errorHandler)
          await catalog.fetchItems()
        }
        .task { await cardMenu.refreshFolders() }
        .mediaCardNewFolderAlert(cardMenu)
    }
    .environment(\.zoomTransitionNamespace, zoomNamespace)
    .navigationStackActive(for: tab, selected: navigationState.selectedTab)
  }

  private var sortToolbarPlacement: ToolbarItemPlacement {
#if os(iOS) || os(tvOS)
    .topBarTrailing
#elseif os(macOS)
    .automatic
#endif
  }

  @ViewBuilder
  var catalogView: some View {
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
}
