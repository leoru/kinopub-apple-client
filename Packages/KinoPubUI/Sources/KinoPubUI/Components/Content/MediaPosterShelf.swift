//
//  MediaPosterShelf.swift
//  KinoPubUI
//
//  One horizontal poster section for Home rows, detail Similar / person shelves,
//  Library shelves — same metrics, same card, optional navigable title.
//

import SwiftUI

/// Horizontal poster (or landscape) shelf. Home Hot Movies and detail "More from
/// director" are the same component; only title / destination / data differ.
public struct MediaPosterShelf<FocusKey: Hashable>: View {

  private let title: String
  private let count: String?
  private let cards: [MediaCard]
  private let destination: (any Hashable)?
  private let navigationLinkProvider: (MediaCard) -> any Hashable
  private let onPlay: ((MediaCard) -> Void)?
  private let contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])?
  private let caption: MediaCardCaption
  private let focusedCard: FocusState<FocusKey?>.Binding?
  private let focusKey: ((MediaCard) -> FocusKey)?
  private let onCardFocused: (() -> Void)?

  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.usesTVUIKitPosters) private var usesTVUIKitPosters
  @Environment(\.mediaNavigation) private var mediaNavigation
  @State private var containerWidth: CGFloat = 1920

  public init(
    title: String,
    count: String? = nil,
    cards: [MediaCard],
    destination: (any Hashable)? = nil,
    navigationLinkProvider: @escaping (MediaCard) -> any Hashable,
    onPlay: ((MediaCard) -> Void)? = nil,
    contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])? = nil,
    caption: MediaCardCaption? = nil,
    focusedCard: FocusState<FocusKey?>.Binding? = nil,
    focusKey: ((MediaCard) -> FocusKey)? = nil,
    onCardFocused: (() -> Void)? = nil
  ) {
    self.title = title
    self.count = count
    self.cards = cards
    self.destination = destination
    self.navigationLinkProvider = navigationLinkProvider
    self.onPlay = onPlay
    self.contextMenuProvider = contextMenuProvider
#if os(tvOS)
    self.caption = caption ?? .onFocus
#else
    self.caption = caption ?? .always
#endif
    self.focusedCard = focusedCard
    self.focusKey = focusKey
    self.onCardFocused = onCardFocused
  }

  private var isLandscape: Bool {
    cards.first?.isLandscape == true
  }

  private var metrics: ShelfMetrics {
    isLandscape
      ? .landscape(width: containerWidth, typeSize: typeSize)
      : .posters(width: containerWidth, typeSize: typeSize)
  }

  private var railFocusPadding: CGFloat {
    isLandscape ? Metrics.landscapeFocusPadding : Metrics.focusPadding
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
        .padding(.horizontal, metrics.inset)

#if os(tvOS)
      if usesTVUIKitPosters {
        tvUIKitRail
      } else {
        swiftUIRail
      }
#else
      swiftUIRail
#endif
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      if width > 0 { containerWidth = width }
    }
  }

  @ViewBuilder
  private var header: some View {
    if let destination {
      NavigationLink(value: destination) {
        SectionHeader(title: title, count: count, showsChevron: true)
      }
      .buttonStyle(RowHeaderButtonStyle())
    } else {
      SectionHeader(title: title, count: count, showsChevron: false)
    }
  }

#if os(tvOS)
  private var tvUIKitRail: some View {
    TVUIKitMediaCollection(
      cards: cards,
      axis: .horizontal,
      containerWidth: containerWidth,
      typeSize: typeSize,
      onSelect: { card in open(card) },
      contextMenuProvider: contextMenuProvider
    )
    .frame(height: TVUIKitPosterMetrics.railHeight(
      isLandscape: isLandscape,
      containerWidth: containerWidth,
      typeSize: typeSize
    ))
    .focusSection()
  }
#endif

  private var swiftUIRail: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      // LazyHStack: only on-screen cards decode (Home CW can be 20+ wide stills).
      // Width from `ShelfMetrics`; `scrollClipDisabled` keeps focus lift visible.
      LazyHStack(alignment: .top, spacing: metrics.gutter) {
        ForEach(cards) { card in
          cardLink(card)
            .mediaZoomSource(id: "media-\(card.id)")
            .frame(width: metrics.cardWidth(in: containerWidth))
#if !os(tvOS)
            .buttonStyle(MediaCardButtonStyle())
#endif
            .modifier(MediaPosterShelfFocusModifier(
              focusedCard: focusedCard,
              key: focusKey?(card)
            ))
#if os(tvOS)
            .modifier(MediaPosterShelfFocusReporter(onCardFocused: onCardFocused))
#endif
            .modifier(MediaCardContextMenuModifier(
              isEnabled: contextMenuProvider != nil,
              entriesProvider: { contextMenuProvider?(card) ?? [] }
            ))
        }
      }
      .padding(.horizontal, metrics.inset)
      // Vertical room for `.borderless` focus lift only — horizontal bleed must
      // stay inside `ShelfMetrics.cardWidth` or rails overflow ~2·focusPadding.
      .padding(.vertical, railFocusPadding)
    }
#if os(tvOS)
    .buttonStyle(.borderless)
    .scrollClipDisabled()
    .focusSection()
#endif
  }

  @ViewBuilder
  private func cardLink(_ card: MediaCard) -> some View {
    if card.primaryAction == .play, let onPlay {
      Button {
        onPlay(card)
      } label: {
        MediaCardView(card: card, caption: caption)
      }
    } else {
      NavigationLink(value: navigationLinkProvider(card)) {
        MediaCardView(card: card, caption: caption)
      }
    }
  }

  private func open(_ card: MediaCard) {
    if card.primaryAction == .play, let onPlay {
      onPlay(card)
      return
    }
    mediaNavigation?(navigationLinkProvider(card))
  }
}

/// Convenience when the caller does not need cross-row `@FocusState` keys.
public extension MediaPosterShelf where FocusKey == Int {
  init(
    title: String,
    count: String? = nil,
    cards: [MediaCard],
    destination: (any Hashable)? = nil,
    navigationLinkProvider: @escaping (MediaCard) -> any Hashable,
    onPlay: ((MediaCard) -> Void)? = nil,
    contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])? = nil,
    caption: MediaCardCaption? = nil,
    onCardFocused: (() -> Void)? = nil
  ) {
    self.init(
      title: title,
      count: count,
      cards: cards,
      destination: destination,
      navigationLinkProvider: navigationLinkProvider,
      onPlay: onPlay,
      contextMenuProvider: contextMenuProvider,
      caption: caption,
      focusedCard: nil,
      focusKey: nil,
      onCardFocused: onCardFocused
    )
  }
}

// MARK: - Focus helpers

private struct MediaPosterShelfFocusModifier<FocusKey: Hashable>: ViewModifier {
  var focusedCard: FocusState<FocusKey?>.Binding?
  var key: FocusKey?

  @ViewBuilder
  func body(content: Content) -> some View {
    if let focusedCard, let key {
      content.focused(focusedCard, equals: key)
    } else {
      content
    }
  }
}

#if os(tvOS)
private struct MediaPosterShelfFocusReporter: ViewModifier {
  let onCardFocused: (() -> Void)?
  @Environment(\.isFocused) private var isFocused

  func body(content: Content) -> some View {
    content.onChange(of: isFocused) { _, focused in
      if focused { onCardFocused?() }
    }
  }
}
#endif
