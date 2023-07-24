//
//  File.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI

public struct ContentItemsListView: View {
  
  private var gridItemLayout = [
    GridItem(.flexible()),
    GridItem(.flexible())
  ]
  
  public init() {}
  
  public var body: some View {
    ScrollView {
      LazyVGrid(columns: gridItemLayout, content: {
        ForEach((0...20), id: \.self) { _ in
          ContentItemView()
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
