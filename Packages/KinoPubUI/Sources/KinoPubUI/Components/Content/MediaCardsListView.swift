//
//  MediaCardsListView.swift
//

import Foundation
import SwiftUI

/// Vertical poster-column grid of `MediaCard`s — History, Watchlist, and any other
/// card-backed catalog that is not a full `MediaItem` list.
public struct MediaCardsListView: View {

  public var cards: [MediaCard]
  public var onLoadMoreContent: (MediaCard) -> Void
  public var navigationLinkProvider: (MediaCard) -> any Hashable
  public var contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])?
  private let paginationError: Bool
  private let onRetryPagination: (() -> Void)?

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.usesTVUIKitPosters) private var usesTVUIKitPosters
  @Environment(\.mediaNavigation) private var mediaNavigation
  @State private var containerWidth: CGFloat = 1920

#if os(tvOS)
  @FocusState private var focusedItemID: Int?
#endif

#if os(tvOS)
  static var cardCaption: MediaCardCaption { .onFocus }
#else
  static var cardCaption: MediaCardCaption { .always }
#endif

  /// Same column count as `ContentItemsListView` / Movies — landscape tiles are just shorter.
  private var metrics: ShelfMetrics {
    .posters(width: containerWidth, typeSize: dynamicTypeSize)
  }

  private var gridColumns: [GridItem] {
    Array(
      repeating: GridItem(.flexible(), spacing: metrics.gutter, alignment: .top),
      count: metrics.columns
    )
  }

  public init(cards: [MediaCard],
              onLoadMoreContent: @escaping (MediaCard) -> Void,
              navigationLinkProvider: @escaping (MediaCard) -> any Hashable,
              contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])? = nil,
              paginationError: Bool = false,
              onRetryPagination: (() -> Void)? = nil) {
    self.cards = cards
    self.onLoadMoreContent = onLoadMoreContent
    self.navigationLinkProvider = navigationLinkProvider
    self.contextMenuProvider = contextMenuProvider
    self.paginationError = paginationError
    self.onRetryPagination = onRetryPagination
  }

  public var body: some View {
#if os(tvOS)
    if usesTVUIKitPosters {
      tvUIKitGrid
    } else {
      swiftUIGrid
    }
#else
    swiftUIGrid
#endif
  }

#if os(tvOS)
  private var tvUIKitGrid: some View {
    VStack(spacing: 0) {
      TVUIKitMediaCollection(
        cards: cards,
        axis: .vertical,
        containerWidth: containerWidth,
        typeSize: dynamicTypeSize,
        onSelect: { card in
          mediaNavigation?(navigationLinkProvider(card))
        },
        onNearEnd: { card in
          onLoadMoreContent(card)
        },
        contextMenuProvider: contextMenuProvider
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      if paginationError, let onRetryPagination {
        paginationRetry(onRetryPagination)
      }
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      if width > 0 { containerWidth = width }
    }
  }
#endif

  private var swiftUIGrid: some View {
    ScrollView {
      LazyVGrid(columns: gridColumns, spacing: metrics.gutter) {
        ForEach(cards) { card in
          NavigationLink(value: navigationLinkProvider(card)) {
            MediaCardView(card: card, caption: Self.cardCaption)
              .onAppear { onLoadMoreContent(card) }
          }
#if os(tvOS)
          .buttonStyle(.borderless)
          .focused($focusedItemID, equals: card.id)
#else
          .buttonStyle(MediaCardButtonStyle())
#endif
          .modifier(MediaCardContextMenuModifier(
            isEnabled: contextMenuProvider != nil,
            entriesProvider: { contextMenuProvider?(card) ?? [] }
          ))
        }
      }
      .safeAreaPadding(.horizontal, metrics.inset)
      .padding(.vertical, Metrics.focusPadding)

      if paginationError, let onRetryPagination {
        paginationRetry(onRetryPagination)
      }
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      if width > 0 { containerWidth = width }
    }
#if os(tvOS)
    .defaultFocus($focusedItemID, cards.first?.id)
#else
    // Native fade as the grid passes under the nav bar. A plain `ScrollView` doesn't
    // inherit the edge treatment `List` gets automatically, so it needs asking for
    // explicitly. tvOS has no floating bar over this screen to slide under — see
    // `.claude/skills/apple-chrome/SKILL.md`.
    .scrollEdgeEffectStyle(.automatic, for: .top)
#endif
  }

  @ViewBuilder
  private func paginationRetry(_ action: @escaping () -> Void) -> some View {
    VStack(spacing: 12) {
      Text("Couldn't Load More")
        .font(TypeScale.cardSubtitle)
        .foregroundStyle(Color.KinoPub.subtitle)
      Button("Try Again", action: action)
#if !os(tvOS)
        .buttonStyle(.glass)
        .controlSize(.large)
#endif
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }
}
