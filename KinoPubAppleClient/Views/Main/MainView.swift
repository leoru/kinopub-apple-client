//
//  MainView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubUI

struct MainView: View {
  
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
    NavigationView {
      VStack {
        ContentItemsListView(items: $catalog.items) { item in
          catalog.loadMoreContent(after: item)
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
    }
  }
}

struct MainView_Previews: PreviewProvider {
  static var previews: some View {
    MainView()
  }
}
