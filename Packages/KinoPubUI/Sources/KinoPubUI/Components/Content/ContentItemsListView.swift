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
  public var navigationLinkProvider: (MediaItem) -> any Hashable
  /// Long-press / secondary-click menu. Empty array leaves the poster without one.
  public var contextMenuProvider: ((MediaItem) -> [MediaCardContextEntry])?
  /// Poster tiles drawn while the first page is still unknown, so the grid's
  /// shape is on screen before the response arrives.
  private let placeholderCount: Int
  private let emptyMessage: LocalizedStringKey?
  /// A page past the first failed to load: the grid keeps its items and shows an
  /// inline retry where the missing page would have appeared — never a full-screen
  /// error in place of loaded content.
  private let paginationError: Bool
  private let onRetryPagination: (() -> Void)?
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
              navigationLinkProvider: @escaping (MediaItem) -> any Hashable,
              contextMenuProvider: ((MediaItem) -> [MediaCardContextEntry])? = nil,
              placeholderCount: Int = 0,
              emptyMessage: LocalizedStringKey? = nil,
              paginationError: Bool = false,
              onRetryPagination: (() -> Void)? = nil,
              @ViewBuilder header: () -> Header) {
    self._items = items
    self.onLoadMoreContent = onLoadMoreContent
    self.navigationLinkProvider = navigationLinkProvider
    self.contextMenuProvider = contextMenuProvider
    self.placeholderCount = placeholderCount
    self.emptyMessage = emptyMessage
    self.paginationError = paginationError
    self.onRetryPagination = onRetryPagination
    self.header = header()
  }

  public var body: some View {
    ScrollView {
      // Header (filters, sort) rides in the same scroll as the grid — never pinned
      // above a GeometryReader-sized remnant that steals half the screen.
      VStack(alignment: .leading, spacing: 0) {
        header

        if items.isEmpty, placeholderCount == 0, let emptyMessage {
          UnavailableView(title: emptyMessage, systemImage: "magnifyingglass")
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
                .modifier(MediaCardContextMenuModifier(entries: contextMenuProvider?(item) ?? []))
              }
            }
          }
          .safeAreaPadding(.horizontal, metrics.inset)
          .padding(.vertical, Metrics.focusPadding)

          if paginationError, let onRetryPagination {
            VStack(spacing: 12) {
              Text("Couldn't Load More")
                .font(Font.KinoPub.subheader)
                .foregroundStyle(Color.KinoPub.subtitle)
              Button("Try Again", action: onRetryPagination)
#if !os(tvOS)
                .buttonStyle(.glass)
                .controlSize(.large)
#endif
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
          }
        }
      }
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      if width > 0 { containerWidth = width }
    }
#if os(tvOS)
    // Default priority — `.userInitiated` yanked focus back to the first cell on every
    // return from a detail page.
    .defaultFocus($focusedItemID, items.first?.id)
#else
    // Native fade as the grid passes under the nav bar / search field. A plain
    // `ScrollView` doesn't inherit the edge treatment `List` gets automatically, so it
    // needs asking for explicitly. tvOS has no floating bar over this screen to slide
    // under — see `docs/en/apple-platform/materials-blur-and-chrome.md`.
    .scrollEdgeEffectStyle(.automatic, for: .top)
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
       navigationLinkProvider: @escaping (MediaItem) -> any Hashable,
       contextMenuProvider: ((MediaItem) -> [MediaCardContextEntry])? = nil,
       placeholderCount: Int = 0,
       emptyMessage: LocalizedStringKey? = nil,
       paginationError: Bool = false,
       onRetryPagination: (() -> Void)? = nil) {
    self.init(items: items,
              onLoadMoreContent: onLoadMoreContent,
              navigationLinkProvider: navigationLinkProvider,
              contextMenuProvider: contextMenuProvider,
              placeholderCount: placeholderCount,
              emptyMessage: emptyMessage,
              paginationError: paginationError,
              onRetryPagination: onRetryPagination,
              header: { EmptyView() })
  }
}

struct ContentItemsListView_Previews: PreviewProvider {

  struct Preview: View {
    @State var items: [MediaItem] = [MediaItem.mock()]

    var body: some View {
      ContentItemsListView(items: $items, onLoadMoreContent: { _ in

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
