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
  
  public init(items: Binding<[MediaItem]>) {
    self._items = items
  }
  
  public var body: some View {
    ScrollView {
      LazyVGrid(columns: ContentItemsListView.gridLayout, content: {
        ForEach(items, id: \.id) { item in
          ContentItemView(mediaItem: item)
            .padding(.vertical, 20)
        }
      })
      .padding(.horizontal, 16)
    }
  }
  
}

//#Preview {
//  ContentItemsListView(items: [])
//}
