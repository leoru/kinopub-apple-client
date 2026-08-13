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
  /// The container's own horizontal safe-area inset. Zero on a screen that already
  /// sits inside the safe area; the overscan margin on one that ignores it (the detail
  /// page does, horizontally). `ShelfMetrics` takes the larger of this and its own
  /// design margin, so the header and the rail always share one number.
  @State private var containerSafeArea: CGFloat = 0

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
      ? .landscape(width: containerWidth, typeSize: typeSize, safeArea: containerSafeArea)
      : .posters(width: containerWidth, typeSize: typeSize, safeArea: containerSafeArea)
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
    .onGeometryChange(for: ShelfGeometry.self) { proxy in
      ShelfGeometry(
        width: proxy.size.width,
        safeArea: max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing)
      )
    } action: { geometry in
      if geometry.width > 0 { containerWidth = geometry.width }
      containerSafeArea = max(0, geometry.safeArea)
    }
  }

  @ViewBuilder
  private var header: some View {
#if os(tvOS)
    // Never a link on tvOS. A navigating section header is an iOS/macOS affordance:
    // on a remote it becomes one more focus stop above every single row, which the
    // user has to travel through on the way down the page, and which no Apple tvOS
    // app has. "See all" belongs in the row itself — a trailing card — not in its
    // title. See `docs/archive/plans/detail-page-choreography.md` phase 6.
    SectionHeader(title: title, count: count, showsChevron: false)
#else
    if let destination {
      NavigationLink(value: destination) {
        SectionHeader(title: title, count: count, showsChevron: true)
      }
      .buttonStyle(RowHeaderButtonStyle())
    } else {
      SectionHeader(title: title, count: count, showsChevron: false)
    }
#endif
  }

#if os(tvOS)
  /// Wide rails ride the system's media-item cell; posters stay on `TVPosterView`
  /// (`TVMediaItemContentConfiguration` ships a 16:9 `wideCell()` only).
  @ViewBuilder
  private var tvUIKitRail: some View {
    if isLandscape {
      TVUIKitMediaItemRail(
        items: cards.map(TVUIKitMediaItem.init(card:)),
        contentInset: metrics.inset,
        onSelect: { id in
          if let card = cards.first(where: { $0.id == id }) { open(card) }
        },
        contextMenuProvider: contextMenuProvider.map { provider in
          { id in cards.first(where: { $0.id == id }).map(provider) ?? [] }
        }
      )
      .focusSection()
    } else {
      tvUIKitPosterRail
    }
  }

  private var tvUIKitPosterRail: some View {
    TVUIKitMediaCollection(
      cards: cards,
      axis: .horizontal,
      containerWidth: containerWidth,
      safeArea: containerSafeArea,
      typeSize: typeSize,
      onSelect: { card in open(card) },
      contextMenuProvider: contextMenuProvider
    )
    .frame(height: TVUIKitPosterMetrics.railHeight(
      isLandscape: isLandscape,
      containerWidth: containerWidth,
      typeSize: typeSize,
      safeArea: containerSafeArea
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
