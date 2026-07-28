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
  private let onRowAppear: ((MediaRow) -> Void)?
  /// Long-press menu for a card. Return an empty array to leave the card without one.
  private let contextMenuProvider: ((MediaCard) -> [MediaCardContextAction])?

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
              onRowAppear: ((MediaRow) -> Void)? = nil,
              contextMenuProvider: ((MediaCard) -> [MediaCardContextAction])? = nil) {
    self.rows = rows
    self.bannerCards = bannerCards
    self.navigationLinkProvider = navigationLinkProvider
    self.onRowAppear = onRowAppear
    self.contextMenuProvider = contextMenuProvider
  }

  public var body: some View {
#if os(tvOS)
    // Hand the remote the first banner (or first shelf card) once content exists —
    // otherwise the sidebar keeps focus on launch. Default priority (not
    // `.userInitiated`): returning from a detail page must not yank focus back.
    scroll
      .background(Color.KinoPub.background)
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
      LazyVStack(alignment: .leading, spacing: Self.rowSpacing) {
        if !bannerCards.isEmpty {
          bannerSection
        }

        ForEach(rows) { row in
          section(for: row)
        }
      }
      .padding(.bottom, Self.rowSpacing)
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
          .containerRelativeFrame(.horizontal,
                                  count: metrics.columns,
                                  span: 1,
                                  spacing: metrics.gutter)
#if !os(tvOS)
          .buttonStyle(MediaCardButtonStyle())
#endif
          .focused($focusedCard, equals: CardKey(row: Self.bannerRowID, card: card.id))
        }
      }
      .safeAreaPadding(.horizontal, metrics.inset)
      .padding(.vertical, Metrics.focusPadding)
    }
#if os(tvOS)
    .buttonStyle(.borderless)
    .scrollClipDisabled()
    .focusSection()
#endif
  }

  // MARK: - Catalog rows

  @ViewBuilder
  private func section(for row: MediaRow) -> some View {
    let metrics = shelfMetrics(for: row)
    VStack(alignment: .leading, spacing: 12) {
      header(for: row)
        .safeAreaPadding(.horizontal, metrics.inset)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: metrics.gutter) {
          ForEach(row.cards) { card in
            NavigationLink(value: navigationLinkProvider(card)) {
              MediaCardView(card: card, caption: Self.cardCaption)
            }
            .containerRelativeFrame(.horizontal,
                                    count: metrics.columns,
                                    span: 1,
                                    spacing: metrics.gutter)
#if !os(tvOS)
            .buttonStyle(MediaCardButtonStyle())
#endif
            .focused($focusedCard, equals: CardKey(row: row.id, card: card.id))
            .modifier(MediaCardContextMenuModifier(actions: contextMenuProvider?(card) ?? []))
          }
        }
        .safeAreaPadding(.horizontal, metrics.inset)
        // Focus grows the card past its frame; without room the lift gets clipped.
        .padding(.vertical, Metrics.focusPadding)
      }
#if os(tvOS)
      // Native poster effect on the shelf (not each link): lift / specular / tilt stay
      // one unit. Scroll-clip off so focus scale isn't cropped; focusSection so Up/Down
      // treat the row as a navigable band.
      .buttonStyle(.borderless)
      .scrollClipDisabled()
      .focusSection()
#endif
    }
    .onAppear { onRowAppear?(row) }
  }

  private func shelfMetrics(for row: MediaRow) -> ShelfMetrics {
    if row.cards.first?.isLandscape == true {
      return .landscape(width: containerWidth, typeSize: typeSize)
    }
    return .posters(width: containerWidth, typeSize: typeSize)
  }

  /// A row whose content has a screen of its own gets a focusable title leading to it;
  /// the rest stay plain text.
  @ViewBuilder
  private func header(for row: MediaRow) -> some View {
    if let destination = row.destination {
      NavigationLink(value: destination) {
        RowHeader(row: row, isLink: true)
      }
      .buttonStyle(RowHeaderButtonStyle())
    } else {
      RowHeader(row: row, isLink: false)
    }
  }

  // MARK: - Metrics

#if os(tvOS)
  /// The focused card names itself in one line underneath. Only on focus, over
  /// space kept reserved so the row doesn't reflow.
  static let cardCaption: MediaCardCaption = .onFocus

  static let rowSpacing: CGFloat = Metrics.rowSpacing
  static let headerFont: Font = TypeScale.rowHeader
  static let countFont: Font = TypeScale.rowCount
  static let chevronFont: Font = TypeScale.rowChevron
#else
  /// No focus off TV — the cards have to name themselves.
  static let cardCaption: MediaCardCaption = .always

  static let rowSpacing: CGFloat = Metrics.rowSpacing
  static let headerFont: Font = TypeScale.rowHeader
  static let countFont: Font = TypeScale.rowCount
  static let chevronFont: Font = TypeScale.rowChevron
#endif
}

/// The row title, its item count, and — where the row leads somewhere — a chevron.
private struct RowHeader: View {
  let row: MediaRow
  let isLink: Bool

  @Environment(\.cardFocused) private var focused

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(row.title)
        .font(MediaRowsView.headerFont)
        .foregroundStyle(Color.KinoPub.text)

      if let count = row.count, !count.isEmpty {
        Text(count)
          .font(MediaRowsView.countFont)
          .foregroundStyle(Color.KinoPub.subtitle)
      }

      if isLink {
        Image(systemName: "chevron.forward")
          .font(MediaRowsView.chevronFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .opacity(chevronOpacity)
      }
    }
    // The title is short, but the focus engine only moves up into what sits directly
    // above the focused card — anything narrower is unreachable from most of the row.
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }

  /// On TV the chevron is focus feedback, the way the Apple TV app only shows "See All"
  /// under the remote. Elsewhere there is no focus to wait for, so it always shows.
  private var chevronOpacity: Double {
#if os(tvOS)
    focused ? 1 : 0
#else
    1
#endif
  }
}

/// Lifts the row title on focus. The stock tvOS button styles would wrap it in a filled
/// card, which is not how a section header reads.
struct RowHeaderButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
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
public struct MediaCardContextMenuModifier: ViewModifier {
  let actions: [MediaCardContextAction]

  public init(actions: [MediaCardContextAction]) {
    self.actions = actions
  }

  @ViewBuilder
  public func body(content: Content) -> some View {
    if actions.isEmpty {
      content
    } else {
      content.contextMenu {
        ForEach(actions) { action in
          Button(role: action.role, action: action.handler) {
            Label(action.title, systemImage: action.systemImage)
          }
        }
      }
    }
  }
}
