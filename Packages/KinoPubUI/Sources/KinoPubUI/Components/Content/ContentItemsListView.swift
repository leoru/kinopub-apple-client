//
//  ContentItemsListView.swift
//
//
//  Created by Kirill Kunst on 24.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

public struct ContentItemsListView<Header: View>: View {

  var width: CGFloat
  @Binding public var items: [MediaItem]
  public var onLoadMoreContent: (MediaItem) -> Void
  public var onRefresh: @Sendable () async -> Void
  public var navigationLinkProvider: (MediaItem) -> any Hashable
  /// Poster tiles drawn while the first page is still unknown, so the grid's
  /// shape is on screen before the response arrives.
  private let placeholderCount: Int
  private let emptyMessage: LocalizedStringKey?
  private let header: Header

#if os(iOS)
  @Environment(\.horizontalSizeClass) private var sizeClass
#endif
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

#if os(tvOS)
  @FocusState private var focusedItemID: Int?
  @State private var hasClaimedFocus = false
#endif

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
#if os(tvOS)
    return MediaCardView.cardWidth
#else
    return useReducedThumbnailSize ? 140 : 180
#endif
  }

  /// A grid has no preview above it, so the focused card is what names the item.
#if os(tvOS)
  static var cardCaption: MediaCardCaption { .onFocus }
#else
  static var cardCaption: MediaCardCaption { .always }
#endif

  var gridLayout: [GridItem] {
    [GridItem(.adaptive(minimum: cellSize), spacing: 25, alignment: .top)]
  }

  public init(width: CGFloat,
              items: Binding<[MediaItem]>,
              onLoadMoreContent: @escaping (MediaItem) -> Void,
              onRefresh: @escaping @Sendable () async -> Void,
              navigationLinkProvider: @escaping (MediaItem) -> any Hashable,
              placeholderCount: Int = 0,
              emptyMessage: LocalizedStringKey? = nil,
              @ViewBuilder header: () -> Header) {
    self._items = items
    self.width = width
    self.onRefresh = onRefresh
    self.onLoadMoreContent = onLoadMoreContent
    self.navigationLinkProvider = navigationLinkProvider
    self.placeholderCount = placeholderCount
    self.emptyMessage = emptyMessage
    self.header = header()
  }

  public var body: some View {
    ScrollView {
      // Header (filters, sort) rides in the same scroll as the grid — never pinned
      // above a GeometryReader-sized remnant that steals half the screen.
      VStack(alignment: .leading, spacing: 0) {
        header

        if items.isEmpty, placeholderCount == 0, let emptyMessage {
          Text(emptyMessage)
            .foregroundStyle(Color.KinoPub.text)
            .font(Font.KinoPub.subheader)
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
          LazyVGrid(columns: gridLayout, content: {
            if items.isEmpty, placeholderCount > 0 {
              ForEach(0..<placeholderCount, id: \.self) { _ in
                placeholderCard
              }
            } else {
              ForEach(items, id: \.id) { item in
                NavigationLink(value: navigationLinkProvider(item)) {
                  MediaCardView(card: MediaCard(item), caption: Self.cardCaption)
                    .padding(.vertical, 20)
                    .onAppear {
                      onLoadMoreContent(item)
                    }
                }
#if os(tvOS)
                .buttonStyle(.borderless)
                .focused($focusedItemID, equals: item.id)
#else
                .buttonStyle(MediaCardButtonStyle())
#endif
              }
            }
          })
          .padding(.horizontal, 16)
        }
      }
    }
    .refreshable(action: onRefresh)
#if os(tvOS)
    .defaultFocus($focusedItemID, items.first?.id, priority: .userInitiated)
    .task(id: items.first?.id) {
      guard !hasClaimedFocus, let firstID = items.first?.id else { return }
      try? await Task.sleep(for: .milliseconds(120))
      guard !Task.isCancelled, focusedItemID == nil else { return }
      focusedItemID = firstID
      hasClaimedFocus = true
    }
#endif
  }

  /// Same footprint as a real poster card (tile + caption line), inert so focus
  /// stays on the filters / search field while the page is still loading.
  private var placeholderCard: some View {
    VStack(alignment: .center, spacing: MediaCardView.captionSpacing) {
      Color.KinoPub.placeholder
        .frame(width: MediaCardView.cardWidth, height: MediaCardView.posterHeight)
        .clipShape(RoundedRectangle(cornerRadius: MediaCardView.cornerRadius, style: .continuous))

      Text(" ")
        .font(MediaCardView.titleFont)
        .opacity(0)
        .frame(width: MediaCardView.cardWidth)
    }
    .frame(width: MediaCardView.cardWidth)
    .padding(.vertical, 20)
    .accessibilityHidden(true)
  }

}

public extension ContentItemsListView where Header == EmptyView {
  init(width: CGFloat,
       items: Binding<[MediaItem]>,
       onLoadMoreContent: @escaping (MediaItem) -> Void,
       onRefresh: @escaping @Sendable () async -> Void,
       navigationLinkProvider: @escaping (MediaItem) -> any Hashable,
       placeholderCount: Int = 0,
       emptyMessage: LocalizedStringKey? = nil) {
    self.init(width: width,
              items: items,
              onLoadMoreContent: onLoadMoreContent,
              onRefresh: onRefresh,
              navigationLinkProvider: navigationLinkProvider,
              placeholderCount: placeholderCount,
              emptyMessage: emptyMessage,
              header: { EmptyView() })
  }
}

struct ContentItemsListView_Previews: PreviewProvider {

  struct Preview: View {
    @State var items: [MediaItem] = [MediaItem.mock()]

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
