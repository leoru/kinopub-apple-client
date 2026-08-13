//
//  MediaRowsView.swift
//
//

import Foundation
import SwiftUI

/// One titled, horizontally scrolling row of cards.
public struct MediaRow: Identifiable {
  public let id: String
  public let title: String
  /// Sits beside the title in secondary type — how many items the row stands for.
  public let count: String?
  public let cards: [MediaCard]
  /// Where the title leads: the same content as a full screen. Nil leaves the title
  /// as plain text, for rows that have no page of their own.
  public let destination: (any Hashable)?

  public init(id: String,
              title: String,
              count: String? = nil,
              cards: [MediaCard],
              destination: (any Hashable)? = nil) {
    self.id = id
    self.title = title
    self.count = count
    self.cards = cards
    self.destination = destination
  }
}

/// The home layout: optional contained banner shelf, then stacked rows of artwork.
public struct MediaRowsView: View {

  private let rows: [MediaRow]
  /// Contained 16:9 featured cards shown above the catalog rows (Home). Empty elsewhere.
  private let bannerCards: [MediaCard]
  private let navigationLinkProvider: (MediaCard) -> any Hashable
  /// When a card's `primaryAction` is `.play`, Select/click runs this instead of navigating.
  private let onPlay: ((MediaCard) -> Void)?
  private let onRowAppear: ((MediaRow) -> Void)?
  /// Long-press menu for a card. Return an empty array to leave the card without one.
  /// `surface` distinguishes shelf lockups from featured banners (artwork URL, etc.).
  private let contextMenuProvider: ((MediaCard, MediaCardContextSurface) -> [MediaCardContextEntry])?

  /// Identifies one card in one row. The same item can sit in two rows — Continue
  /// Watching and Hot Series both — so the card's own id is not unique enough to
  /// track focus by.
  private struct CardKey: Hashable {
    let row: String
    let card: Int
  }

  private static let bannerRowID = "__banner__"

  @FocusState private var focusedCard: CardKey?
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var containerWidth: CGFloat = 1920

  public init(rows: [MediaRow],
              bannerCards: [MediaCard] = [],
              navigationLinkProvider: @escaping (MediaCard) -> any Hashable,
              onPlay: ((MediaCard) -> Void)? = nil,
              onRowAppear: ((MediaRow) -> Void)? = nil,
              contextMenuProvider: ((MediaCard, MediaCardContextSurface) -> [MediaCardContextEntry])? = nil) {
    self.rows = rows
    self.bannerCards = bannerCards
    self.navigationLinkProvider = navigationLinkProvider
    self.onPlay = onPlay
    self.onRowAppear = onRowAppear
    self.contextMenuProvider = contextMenuProvider
  }

  public var body: some View {
#if os(tvOS)
    // Hand the remote the first banner (or first shelf card) once content exists —
    // otherwise the sidebar keeps focus on launch. Default priority (not
    // `.userInitiated`): returning from a detail page must not yank focus back.
    scroll
      .defaultFocus($focusedCard, firstCardKey)
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { width in
        if width > 0 { containerWidth = width }
      }
#else
    scroll
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { width in
        if width > 0 { containerWidth = width }
      }
#endif
  }

  private var scroll: some View {
    ScrollView(.vertical) {
      // Lazy on every platform — an eager VStack on tvOS decoded every Home poster
      // at once (1GB+ / CVPixelBuffer -6680). Focus lift room comes from
      // `scrollClipDisabled` + per-rail vertical padding, not from realizing all rows.
      LazyVStack(alignment: .leading, spacing: Self.rowSpacing) {
        scrollContent
      }
      .padding(.bottom, Self.rowSpacing)
    }
#if os(tvOS)
    .scrollClipDisabled()
#else
    // Native fade as rows pass under the nav bar / large title. A plain `ScrollView`
    // doesn't inherit the edge treatment `List` gets automatically, so it needs asking
    // for explicitly. tvOS has no floating bar over this screen to slide under — see
    // `.claude/skills/apple-chrome/SKILL.md`.
    .scrollEdgeEffectStyle(.automatic, for: .top)
#endif
  }

  @ViewBuilder
  private var scrollContent: some View {
    if !bannerCards.isEmpty {
      bannerSection
    }

    ForEach(rows) { row in
      section(for: row)
    }
  }

#if os(tvOS)
  private var firstCardKey: CardKey? {
    if let card = bannerCards.first {
      return CardKey(row: Self.bannerRowID, card: card.id)
    }
    guard let row = rows.first, let card = row.cards.first else { return nil }
    return CardKey(row: row.id, card: card.id)
  }
#endif

  // MARK: - Banner

  @ViewBuilder
  private var bannerSection: some View {
    let metrics = ShelfMetrics.banner(width: containerWidth, typeSize: typeSize)
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: metrics.gutter) {
        ForEach(bannerCards) { card in
          NavigationLink(value: navigationLinkProvider(card)) {
            HomeBannerCardView(card: card)
          }
          .mediaZoomSource(id: "media-\(card.id)")
          .containerRelativeFrame(.horizontal,
                                  count: metrics.columns,
                                  span: 1,
                                  spacing: metrics.gutter)
#if !os(tvOS)
          .buttonStyle(MediaCardButtonStyle())
#endif
          .focused($focusedCard, equals: CardKey(row: Self.bannerRowID, card: card.id))
          .modifier(MediaCardContextMenuModifier(
            isEnabled: contextMenuProvider != nil,
            entriesProvider: { contextMenuProvider?(card, .banner) ?? [] }
          ))
        }
      }
      .scrollTargetLayout()
      .safeAreaPadding(.horizontal, metrics.inset)
      .padding(.vertical, Metrics.focusPadding)
    }
    .scrollTargetBehavior(.viewAligned)
#if os(tvOS)
    .buttonStyle(.borderless)
    .scrollClipDisabled()
    .focusSection()
#endif
  }

  // MARK: - Catalog rows

  @ViewBuilder
  private func section(for row: MediaRow) -> some View {
    MediaPosterShelf(
      title: row.title,
      count: row.count,
      cards: row.cards,
      destination: row.destination,
      navigationLinkProvider: navigationLinkProvider,
      onPlay: onPlay,
      contextMenuProvider: { card in
        contextMenuProvider?(card, .shelf) ?? []
      },
      caption: Self.cardCaption,
      focusedCard: $focusedCard,
      focusKey: { CardKey(row: row.id, card: $0.id) }
    )
    .onAppear { onRowAppear?(row) }
  }

  // MARK: - Metrics

#if os(tvOS)
  /// The focused card names itself in one line underneath. Only on focus, over
  /// space kept reserved so the row doesn't reflow.
  static let cardCaption: MediaCardCaption = .onFocus

  static let rowSpacing: CGFloat = Metrics.rowSpacing
#else
  /// No focus off TV — the cards have to name themselves.
  static let cardCaption: MediaCardCaption = .always

  static let rowSpacing: CGFloat = Metrics.rowSpacing
#endif
}

/// Lifts the row title on focus. The stock tvOS button styles would wrap it in a filled
/// card, which is not how a section header reads.
public struct RowHeaderButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    Header(configuration: configuration)
  }

  private struct Header: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .environment(\.cardFocused, isFocused)
        .scaleEffect(isFocused ? 1.06 : 1.0, anchor: .leading)
        .opacity(configuration.isPressed ? 0.6 : 1)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }
  }
}

/// The off-tvOS card style: a press scale, no focus (there is none on iOS/macOS). On tvOS
/// the cards use the native `.borderless` style instead, which brings the real system
/// parallax — so nothing here is tvOS-specific any more.
public struct MediaCardButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// Applies a long-press context menu when there is something to offer; a no-op otherwise
/// so catalog posters without actions stay clean.
///
/// Entries are built **inside** `contextMenu` so providers that touch coordinators
/// don't run for every visible card on every Home body pass (that path previously
/// stormed `get-item-folders` and froze macOS).
public struct MediaCardContextMenuModifier: ViewModifier {
  private let isEnabled: Bool
  private let entriesProvider: () -> [MediaCardContextEntry]

  public init(entries: [MediaCardContextEntry]) {
    self.isEnabled = !entries.isEmpty
    self.entriesProvider = { entries }
  }

  public init(isEnabled: Bool, entriesProvider: @escaping () -> [MediaCardContextEntry]) {
    self.isEnabled = isEnabled
    self.entriesProvider = entriesProvider
  }

  @ViewBuilder
  public func body(content: Content) -> some View {
    if isEnabled {
      content.contextMenu {
        ForEach(entriesProvider()) { entry in
          entryView(entry)
        }
        // macOS 26+/27 hide SF Symbol menu icons unless we ask for title+icon.
        .labelStyle(.titleAndIcon)
      }
    } else {
      content
    }
  }

  @ViewBuilder
  private func entryView(_ entry: MediaCardContextEntry) -> some View {
    switch entry {
    case .action(let action):
      contextControl(action)
    case .submenu(_, let title, let systemImage, let children, let footer):
      Menu {
        ForEach(children) { child in
          contextControl(child)
        }
        if !footer.isEmpty {
          Divider()
          ForEach(footer) { item in
            contextControl(item)
          }
        }
      } label: {
        Label(title, systemImage: systemImage)
      }
      .labelStyle(.titleAndIcon)
    case .divider:
      Divider()
    }
  }

  @ViewBuilder
  private func contextControl(_ action: MediaCardContextAction) -> some View {
    if action.isSelection {
      Toggle(isOn: Binding(
        get: { action.isOn },
        set: { _ in action.handler() }
      )) {
        Text(action.title)
      }
    } else {
      Button(role: action.role, action: action.handler) {
        Label(action.title, systemImage: action.systemImage)
      }
      .labelStyle(.titleAndIcon)
    }
  }
}

#Preview("Home rows + banner") {
  NavigationStack {
    MediaRowsView(
      rows: [
        MediaRow(
          id: "hot",
          title: "Hot Films",
          count: "12",
          cards: [
            MediaCard(
              id: 1,
              posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
              title: "Стражи",
              imdbRating: 8.1,
              kinopoiskRating: 8.3,
              is4K: true,
              isHDR: true
            ),
            MediaCard(
              id: 2,
              posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
              title: "Другой фильм",
              imdbRating: 7.2,
              kinopoiskRating: 7.0,
              badge: "+3",
              is4K: true
            )
          ],
          destination: "hot"
        )
      ],
      bannerCards: [
        MediaCard(
          id: 10,
          posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
          title: "Баннер",
          subtitle: "Featured",
          imdbRating: 7.8,
          kinopoiskRating: 7.5,
          backdropURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
          is4K: true,
          isHDR: true
        )
      ],
      navigationLinkProvider: { card in card.id }
    )
  }
  .preferredColorScheme(.dark)
}
