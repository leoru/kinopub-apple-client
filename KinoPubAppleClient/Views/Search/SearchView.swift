//
//  SearchView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Search, sorting and filtering all live here so the Main tab can be a pure
/// browse surface (rows of artwork) the way tvOS apps present a home screen.
struct SearchView: View {
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var authState: AuthState
  @Environment(\.appContext) var appContext

  @StateObject private var catalog: LibraryCatalog
  /// What the search field shows. When this matches `filterFieldAnchor`, the
  /// catalog is filter-driven (query stays empty so the filter bar stays up).
  @State private var searchFieldText = ""
  /// The label we stuffed into the field for a filter jump — editing away from
  /// it switches to a normal text search.
  @State private var filterFieldAnchor: String?
  @State private var navigationTitleText: String = "Search".localized

  init(catalog: @autoclosure @escaping () -> LibraryCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }

  /// Enough empty posters to sketch a couple of rows before the page arrives.
  private static let placeholderCount = 12

  var body: some View {
    NavigationStack(path: $navigationState.searchRoutes) {
      GeometryReader { geometryProxy in
        ContentItemsListView(
          width: geometryProxy.size.width,
          items: $catalog.items,
          onLoadMoreContent: { item in
            catalog.loadMoreContent(after: item)
          },
          onRefresh: {
            await catalog.refresh()
          },
          navigationLinkProvider: { item in
            SearchRoutesLinkProvider().link(for: item)
          },
          placeholderCount: showsPlaceholders ? Self.placeholderCount : 0,
          emptyMessage: showsEmptyMessage ? "No Results" : nil
        ) {
#if os(tvOS)
          if navigationState.canReturnFromSearch {
            tvBackRow
          }
#endif
          // Filters scroll away with the grid — pinning them above a remnant
          // GeometryReader was eating half the screen and delaying `.searchable`.
          if !catalog.isSearching {
            LibraryFiltersBar(catalog: catalog)
          }
        }
      }
      .searchable(text: $searchFieldText, placement: .automatic)
      .platformNavigationTitle(navigationTitleText)
//      .background(Color.KinoPub.background)
#if !os(tvOS)
      .toolbar {
        if navigationState.canReturnFromSearch {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              navigationState.returnFromSearch()
            } label: {
              Label("Back", systemImage: "chevron.backward")
            }
          }
        }
      }
#endif
      .navigationDestination(for: SearchRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              knownItem: item,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: SearchRoutesLinkProvider(),
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
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: SearchRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: SearchRoutesLinkProvider()))
        case .person(let person):
          PersonItemsView.make(person: person,
                               linkProvider: SearchRoutesLinkProvider(),
                               context: appContext,
                               authState: authState,
                               errorHandler: errorHandler)
        }
      }
      .handleError(state: $errorHandler.state)
      .task {
        if let pending = navigationState.pendingSearch {
          navigationState.pendingSearch = nil
          applyPending(pending)
        } else {
          await catalog.load()
        }
      }
      .onChange(of: navigationState.pendingSearch) { _, pending in
        guard let pending else { return }
        navigationState.pendingSearch = nil
        applyPending(pending)
      }
      .onChange(of: searchFieldText) { _, newValue in
        handleSearchFieldChange(newValue)
      }
    }
    .navigationStackActive(for: .search, selected: navigationState.selectedTab)
  }

  private var tvBackRow: some View {
    Button {
      navigationState.returnFromSearch()
    } label: {
      Label(backLabel, systemImage: "chevron.backward")
        .font(LibraryFiltersBar.font)
    }
    .buttonStyle(.borderless)
    .padding(.bottom, 8)
  }

  private var backLabel: String {
    guard let tab = navigationState.searchReturnTab else { return "Back".localized }
    switch tab {
    case .home: return "For You".localized
    case .movies: return "Movies".localized
    case .series: return "Series".localized
    case .library: return "Library".localized
    case .watchlist: return "Watchlist".localized
    case .recentlyWatched: return "Recently Watched".localized
    case .bookmarks, .bookmark: return "Bookmarks".localized
    default: return "Back".localized
    }
  }

  private func applyPending(_ pending: PendingSearch) {
    filterFieldAnchor = pending.title
    searchFieldText = pending.title
    navigationTitleText = pending.title
    catalog.applyExternalFilter(pending.filter)
  }

  private func handleSearchFieldChange(_ newValue: String) {
    if let anchor = filterFieldAnchor {
      guard newValue != anchor else { return }
      filterFieldAnchor = nil
      navigationTitleText = "Search".localized
      catalog.clearFilters()
      catalog.query = newValue
      return
    }
    catalog.query = newValue
    if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
      navigationTitleText = "Search".localized
    }
  }

  private var showsPlaceholders: Bool {
    catalog.items.isEmpty && catalog.isLoading
  }

  private var showsEmptyMessage: Bool {
    catalog.items.isEmpty && catalog.isSearching && !catalog.isLoading
  }
}

struct SearchView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()

  static var previews: some View {
    SearchView(catalog: LibraryCatalog(itemsService: VideoContentServiceMock(),
                                       authState: AuthState(authService: AuthorizationServiceMock(),
                                                            accessTokenService: AccessTokenServiceMock()),
                                       errorHandler: ErrorHandler()))
    .environmentObject(navState)
  }
}
