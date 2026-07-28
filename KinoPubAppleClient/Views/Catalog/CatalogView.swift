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
        .navigationDestination(for: CatalogRoutes.self) { route in
          switch route {
          case .details(let item):
            MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                                knownItem: item,
                                                itemsService: appContext.contentService,
                                                downloadManager: appContext.downloadManager,
                                                linkProvider: CatalogRoutesLinkProvider(),
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
            SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: CatalogRoutesLinkProvider()))
          case .season(let season):
            SeasonView(model: SeasonModel(season: season, linkProvider: CatalogRoutesLinkProvider()))
          case .person(let person):
            PersonItemsView.make(person: person,
                                 linkProvider: CatalogRoutesLinkProvider(),
                                 context: appContext,
                                 authState: authState,
                                 errorHandler: errorHandler)
          }
        }
        .handleError(state: $errorHandler.state)
        .task {
          await catalog.fetchItems()
        }
    }
    .navigationStackActive(for: tab, selected: navigationState.selectedTab)
  }

  @ViewBuilder
  var catalogView: some View {
    if catalog.items.isEmpty && catalog.isLoading {
      LoadingIndicatorView()
    } else {
      grid
    }
  }

  private var grid: some View {
    ContentItemsListView(items: $catalog.items, onLoadMoreContent: { item in
      catalog.loadMoreContent(after: item)
    }, onRefresh: {
      await catalog.refresh()
    }, navigationLinkProvider: { item in
      CatalogRoutesLinkProvider().link(for: item)
    })
  }
}
