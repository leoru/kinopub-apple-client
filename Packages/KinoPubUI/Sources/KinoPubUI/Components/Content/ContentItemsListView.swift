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
  
  private var gridItemLayout = [
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]
  
  @State var items: [MediaItem] = []
  
  public init() {}
  
  public var body: some View {
    ScrollView {
      LazyVGrid(columns: gridItemLayout, content: {
        ForEach(items, id: \.id) { item in
          ContentItemView(mediaItem: item)
            .padding(.vertical, 20)
        }
      })
      .padding(.horizontal, 16)
    }
  }
  
}

#Preview {
  ContentItemsListView()
}
