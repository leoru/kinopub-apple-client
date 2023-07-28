//
//  File.swift
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
  
  public init(items: Binding<[MediaItem]>, onLoadMoreContent: @escaping (MediaItem) -> Void) {
    self._items = items
    self.onLoadMoreContent = onLoadMoreContent
  }
  
  public var body: some View {
    ScrollView {
      LazyVGrid(columns: ContentItemsListView.gridLayout, content: {
        ForEach(items, id: \.id) { item in
          ContentItemView(mediaItem: item)
            .padding(.vertical, 20)
            .onAppear {
              onLoadMoreContent(item)
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
