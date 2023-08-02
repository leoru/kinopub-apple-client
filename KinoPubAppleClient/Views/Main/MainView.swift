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
  
  @StateObject private var catalog: MediaCatalog = MediaCatalog(itemsService: AppContext.shared.contentService)
  
  @State private var showShortCutPicker: Bool = false
  
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
      .navigationTitle(catalog.title)
      .toolbar {
        ToolbarItem(placement: toolbarItemPlacement) {
          Button {
            
          } label: {
            Image(systemName: "magnifyingglass")
          }
        }
        ToolbarItem(placement: toolbarItemPlacement) {
          Button {
            showShortCutPicker = true
          } label: {
            Image(systemName: "arrow.up.arrow.down")
          }
        }
        
        ToolbarItem(placement: toolbarItemPlacement) {
          Button {
            
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
          }
        }
      }
      .background(Color.KinoPub.background)
      .onAppear(perform: {
        Task {
          await catalog.fetchItems()
        }
      })
      .sheet(isPresented: $showShortCutPicker, content: {
        ShortcutSelectionView(shortcut: $catalog.shortcut,
                              mediaType: $catalog.contentType)
      })
      .navigationDestination(for: MainRoutes.self) { route in
        switch route {
        case .details(let item):
          MediaItemView(mediaItem: item)
        }
      }
    }
  }
}

struct MainView_Previews: PreviewProvider {
  @StateObject static var navState = NavigationState()
  
  static var previews: some View {
    MainView()
      .environmentObject(navState)
  }
}
