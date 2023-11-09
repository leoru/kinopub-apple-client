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
  @Environment(\.appContext) var appContext
  
  @StateObject private var catalog: MediaCatalog
  @State private var showShortCutPicker: Bool = false
  @State private var showFilterPicker: Bool = false
  
  init(catalog: @autoclosure @escaping () -> MediaCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var toolbarItemPlacement: ToolbarItemPlacement {
#if os(iOS)
    .topBarTrailing
#elseif os(macOS)
    .navigation
#endif
  }
  
  var body: some View {
    NavigationStack(path: $navigationState.mainRoutes) {
      VStack {
        if catalog.items.isEmpty && !catalog.query.isEmpty {
          emptyView
        } else {
          catalogView
        }
      }
      .searchable(text: $catalog.query, placement: .automatic)
      .navigationTitle(catalog.title.localized)
      .toolbar {
        ToolbarItem(placement: toolbarItemPlacement) {
          Button {
            showShortCutPicker = true
          } label: {
            Image(systemName: "arrow.up.arrow.down")
          }
        }
        
        ToolbarItem(placement: toolbarItemPlacement) {
          Button {
            showFilterPicker = true
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
          }
        }
      }
      .background(Color.KinoPub.background)
      .sheet(isPresented: $showShortCutPicker, content: {
        ShortcutSelectionView(shortcut: $catalog.shortcut,
                              mediaType: $catalog.contentType)
      })
      .sheet(isPresented: $showFilterPicker, content: {
        FilterView(model: FilterModel())
      })
      .navigationDestination(for: MainRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(model: MediaItemModel(mediaItemId: item.id,
                                              itemsService: appContext.contentService,
                                              downloadManager: appContext.downloadManager,
                                              linkProvider: MainRoutesLinkProvider(),
                                              errorHandler: errorHandler))
        case .player(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .media,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase))
        case .trailerPlayer(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .trailer,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase))
        case .seasons(let seasons):
          SeasonsView(model: SeasonsModel(seasons: seasons, linkProvider: MainRoutesLinkProvider()))
        case .season(let season):
          SeasonView(model: SeasonModel(season: season, linkProvider: MainRoutesLinkProvider()))
        }
      }
      .handleError(state: $errorHandler.state)
      .task {
        await catalog.fetchItems()
      }
    }
  }
  
  var catalogView: some View {
    GeometryReader { geometryProxy in
      ContentItemsListView(width: geometryProxy.size.width, items: $catalog.items, onLoadMoreContent: { item in
        catalog.loadMoreContent(after: item)
      }, onRefresh: {
        await catalog.refresh()
      }, navigationLinkProvider: { item in
        MainRoutesLinkProvider().link(for: item)
      })
    }
  }
  
  var emptyView: some View {
    Text("No resuts")
      .foregroundStyle(Color.KinoPub.text)
      .font(Font.KinoPub.subheader)
  }
}

struct MainView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()
  
  static var previews: some View {
    MainView(catalog: MediaCatalog(itemsService: VideoContentServiceMock(), authState: AuthState(authService: AuthorizationServiceMock(), accessTokenService: AccessTokenServiceMock()), errorHandler: ErrorHandler()))
      .environmentObject(navState)
  }
}
