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
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  private let title: LocalizedStringKey
  private let tab: NavigationTabs
  private let path: ReferenceWritableKeyPath<NavigationState, [CatalogRoutes]>

  @StateObject private var catalog: MediaCatalog
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

  var toolbarItemPlacement: ToolbarItemPlacement {
#if os(iOS) || os(tvOS)
    .topBarTrailing
#elseif os(macOS)
    .navigation
#endif
  }

  var body: some View {
    NavigationStack(path: Binding(get: { navigationState[keyPath: path] },
                                  set: { navigationState[keyPath: path] = $0 })) {
      catalogView
        .platformNavigationTitle(title)
        .background(Color.KinoPub.background)
        .toolbar {
          ToolbarItem(placement: toolbarItemPlacement) {
            Button {
              showShortCutPicker = true
            } label: {
              Image(systemName: "arrow.up.arrow.down")
            }
          }
        }
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
          await catalog.fetchItems()
        }
    }
    .environment(\.zoomTransitionNamespace, zoomNamespace)
    .navigationStackActive(for: tab, selected: navigationState.selectedTab)
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
    ContentItemsListView(items: $catalog.items, onLoadMoreContent: { item in
      catalog.loadMoreContent(after: item)
    }, navigationLinkProvider: { item in
      CatalogRoutesLinkProvider().link(for: item)
    }, paginationError: catalog.paginationFailed, onRetryPagination: {
      catalog.retryPagination()
    })
  }
}
