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

  var width: CGFloat
  @Binding public var items: [MediaItem]
  public var onLoadMoreContent: (MediaItem) -> Void
  public var onRefresh: @Sendable () async -> Void
  public var navigationLinkProvider: (MediaItem) -> any Hashable

#if os(iOS)
  @Environment(\.horizontalSizeClass) private var sizeClass
#endif
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var useReducedThumbnailSize: Bool {
#if os(iOS)
    if sizeClass == .compact {
      return true
    }
#endif
    if dynamicTypeSize >= .xxxLarge {
      return true
    }

#if os(iOS)
    if width <= 390 {
      return true
    }
#elseif os(macOS)
    if width <= 520 {
      return true
    }
#endif

    return false
  }

  var cellSize: Double {
    useReducedThumbnailSize ? 140 : 180
  }

  var thumbnailSize: Double {
#if os(iOS)
    return useReducedThumbnailSize ? 60 : 100
#else
    return useReducedThumbnailSize ? 40 : 80
#endif
  }

  var gridLayout: [GridItem] {
    [GridItem(.adaptive(minimum: cellSize), spacing: 25, alignment: .top)]
  }

  public init(width: CGFloat,
              items: Binding<[MediaItem]>,
              onLoadMoreContent: @escaping (MediaItem) -> Void,
              onRefresh: @escaping @Sendable () async -> Void,
              navigationLinkProvider: @escaping (MediaItem) -> any Hashable) {
    self._items = items
    self.width = width
    self.onRefresh = onRefresh
    self.onLoadMoreContent = onLoadMoreContent
    self.navigationLinkProvider = navigationLinkProvider
  }

  public var body: some View {
    ScrollView {
      LazyVGrid(columns: gridLayout, content: {
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
    .refreshable(action: onRefresh)
  }

}

struct ContentItemsListView_Previews: PreviewProvider {

  struct Preview: View {
    @State var items: [MediaItem] = MediaItem.skeletonMock()

    var body: some View {
      GeometryReader { geometryProxy in
        ContentItemsListView(width: geometryProxy.size.width, items: $items, onLoadMoreContent: { _ in

        }, onRefresh: {

        }, navigationLinkProvider: { _ in
          return ""
        })
      }
    }
  }

  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
