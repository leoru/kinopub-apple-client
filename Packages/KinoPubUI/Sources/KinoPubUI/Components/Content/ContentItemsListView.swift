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

  @Binding public var items: [MediaItem]
  public var onLoadMoreContent: (MediaItem) -> Void
  public var onRefresh: @Sendable () async -> Void
  public var navigationLinkProvider: (MediaItem) -> any Hashable
  /// Poster tiles drawn while the first page is still unknown, so the grid's
  /// shape is on screen before the response arrives.
  private let placeholderCount: Int
  private let emptyMessage: LocalizedStringKey?
  private let header: Header

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var containerWidth: CGFloat = 1920

#if os(tvOS)
  @FocusState private var focusedItemID: Int?
#endif

  /// A grid has no preview above it, so the focused card is what names the item.
#if os(tvOS)
  static var cardCaption: MediaCardCaption { .onFocus }
#else
  static var cardCaption: MediaCardCaption { .always }
#endif

  private var metrics: ShelfMetrics {
    .posters(width: containerWidth, typeSize: dynamicTypeSize)
  }

  private var gridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: metrics.gutter, alignment: .top),
      count: metrics.columns
    )
  }

  public init(items: Binding<[MediaItem]>,
              onLoadMoreContent: @escaping (MediaItem) -> Void,
              onRefresh: @escaping @Sendable () async -> Void,
              navigationLinkProvider: @escaping (MediaItem) -> any Hashable,
              placeholderCount: Int = 0,
              emptyMessage: LocalizedStringKey? = nil,
              @ViewBuilder header: () -> Header) {
    self._items = items
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
          LazyVGrid(columns: gridColumns, spacing: metrics.gutter) {
            if items.isEmpty, placeholderCount > 0 {
              ForEach(0..<placeholderCount, id: \.self) { _ in
                placeholderCard
              }
            } else {
              ForEach(items, id: \.id) { item in
                NavigationLink(value: navigationLinkProvider(item)) {
                  MediaCardView(card: MediaCard(item), caption: Self.cardCaption)
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
          }
          .safeAreaPadding(.horizontal, metrics.inset)
          .padding(.vertical, Metrics.focusPadding)
        }
      }
    }
    .refreshable(action: onRefresh)
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      if width > 0 { containerWidth = width }
    }
#if os(tvOS)
    // Default priority — `.userInitiated` yanked focus back to the first cell on every
    // return from a detail page.
    .defaultFocus($focusedItemID, items.first?.id)
#endif
  }

  /// Same footprint as a real poster card (tile + caption line), inert so focus
  /// stays on the filters / search field while the page is still loading.
  private var placeholderCard: some View {
    VStack(alignment: .leading, spacing: Metrics.cardCaptionSpacing) {
      Color.KinoPub.placeholder
        .aspectRatio(CardAspect.poster.ratio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))

      Text(" ")
        .font(TypeScale.cardTitle)
        .opacity(0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityHidden(true)
  }

}

public extension ContentItemsListView where Header == EmptyView {
  init(items: Binding<[MediaItem]>,
       onLoadMoreContent: @escaping (MediaItem) -> Void,
       onRefresh: @escaping @Sendable () async -> Void,
       navigationLinkProvider: @escaping (MediaItem) -> any Hashable,
       placeholderCount: Int = 0,
       emptyMessage: LocalizedStringKey? = nil) {
    self.init(items: items,
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
      ContentItemsListView(items: $items, onLoadMoreContent: { _ in

      }, onRefresh: {

      }, navigationLinkProvider: { _ in
        return ""
      })
    }
  }

  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
