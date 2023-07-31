//
//  ContentItemsListView.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

public struct ContentItemsListView: View {
  
  public static var gridLayout: [GridItem] = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]
  
  @Binding public var items: [MediaItem]
  public var onLoadMoreContent: (MediaItem) -> Void
  public var navigationLinkProvider: (MediaItem) -> any Hashable
  
  public init(items: Binding<[MediaItem]>, onLoadMoreContent: @escaping (MediaItem) -> Void, navigationLinkProvider: @escaping (MediaItem) -> any Hashable) {
    self._items = items
    self.onLoadMoreContent = onLoadMoreContent
    self.navigationLinkProvider = navigationLinkProvider
  }
  
  public var body: some View {
    ScrollView {
      LazyVGrid(columns: ContentItemsListView.gridLayout, content: {
        ForEach(items, id: \.id) { item in
          NavigationLink(value: navigationLinkProvider(item)) {
            ContentItemView(mediaItem: item)
              .padding(.vertical, 20)
              .onAppear {
                onLoadMoreContent(item)
              }
          }
        }
      })
      .padding(.horizontal, 16)
    }
  }
  
}

//#Preview {
//  ContentItemsListView(items: [])
//}
