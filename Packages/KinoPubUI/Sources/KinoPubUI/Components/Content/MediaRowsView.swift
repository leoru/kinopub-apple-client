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

/// The home layout: stacked rows of artwork, the way tvOS apps present a catalog.
public struct MediaRowsView: View {

  private let rows: [MediaRow]
  private let navigationLinkProvider: (MediaCard) -> any Hashable
  private let onRowAppear: ((MediaRow) -> Void)?
  /// Long-press menu for a card. Return an empty array to leave the card without one.
  private let contextMenuProvider: ((MediaCard) -> [MediaCardContextAction])?

  /// tvOS only: the focused-card hero — the reserved space above the rows plus the
  /// full-screen blurred artwork behind everything. Off on Home for now: the progressive
  /// blur re-rendered on every focus move is too heavy on device, and it drew over the tab
  /// bar. The rows-only layout is the fallback until it comes back as a lighter top slider.
  private let showsFeaturedPreview: Bool

  /// Identifies one card in one row. The same item can sit in two rows — Continue
  /// Watching and Hot Series both — so the card's own id is not unique enough to
  /// track focus by.
  private struct CardKey: Hashable {
    let row: String
    let card: Int
  }

  @FocusState private var focusedCard: CardKey?

  /// What the backdrop is showing. Separate from `focusedCard` so the artwork holds
  /// when focus leaves for the tab bar instead of dropping to a bare background.
  @State private var backdropCard: CardKey?

  /// Set once the screen has handed focus to its first card, so coming back from an
  /// item page restores where the user was instead of snapping to the top again.
  @State private var hasClaimedFocus: Bool = false

  public init(rows: [MediaRow],
              navigationLinkProvider: @escaping (MediaCard) -> any Hashable,
              showsFeaturedPreview: Bool = true,
              onRowAppear: ((MediaRow) -> Void)? = nil,
              contextMenuProvider: ((MediaCard) -> [MediaCardContextAction])? = nil) {
    self.rows = rows
    self.navigationLinkProvider = navigationLinkProvider
    self.showsFeaturedPreview = showsFeaturedPreview
    self.onRowAppear = onRowAppear
    self.contextMenuProvider = contextMenuProvider
  }

  public var body: some View {
#if os(tvOS)
    if showsFeaturedPreview {
      // The remote should land on the first card of the first row so the hero above has
      // something to show. `.defaultFocus` alone does not do it: the rows arrive after the
      // screen does, and by then the tab bar already holds focus — so claim it once the
      // first card actually exists.
      scroll
        .background(featuredBackground)
        .defaultFocus($focusedCard, firstCardKey, priority: .userInitiated)
        .onChange(of: focusedCard) { _, newValue in
          // Nil means focus went to the tab bar or a pushed screen; keep the artwork.
          if let newValue { backdropCard = newValue }
        }
        .task {
          guard !hasClaimedFocus, let firstCardKey else { return }
          // The stack is lazy — the card is not there to focus on the same runloop pass.
          try? await Task.sleep(for: .milliseconds(120))
          guard !Task.isCancelled, focusedCard == nil else { return }
          focusedCard = firstCardKey
          hasClaimedFocus = true
        }
    } else {
      // No hero to feed, so no reason to steal focus from the tab bar: let the remote rest
      // there by default, the way a plain rows screen should.
      scroll
        .background(featuredBackground)
    }
#else
    scroll
#endif
  }

  private var scroll: some View {
    ScrollView(.vertical) {
      LazyVStack(alignment: .leading, spacing: Self.rowSpacing) {
#if os(tvOS)
        // Part of the scroll, not a fixed layer: the preview belongs to the top of the
        // page and slides away as focus moves down the rows. Pinned instead, the rows
        // scroll straight over the title and plot.
        if showsFeaturedPreview {
          previewZone
        }
#endif

        ForEach(rows) { row in
          section(for: row)
        }
      }
      .padding(.bottom, Self.rowSpacing)
    }
  }

  // MARK: - Focus backdrop

#if os(tvOS)
  private var firstCardKey: CardKey? {
    guard let row = rows.first, let card = row.cards.first else { return nil }
    return CardKey(row: row.id, card: card.id)
  }

  private func card(for key: CardKey?) -> MediaCard? {
    guard let key else { return nil }
    return rows.first { $0.id == key.row }?.cards.first { $0.id == key.card }
  }

  /// The page background. With the hero on, it's the focused item's blurred artwork; with
  /// it off, a plain fill that leaves the tab bar above uncovered.
  @ViewBuilder
  private var featuredBackground: some View {
    if showsFeaturedPreview {
      backdrop
    } else {
      Color.KinoPub.background
    }
  }

  /// The focused item's wide artwork behind the whole screen, with its title and plot
  /// over the reserved space above the rows — how the Apple TV app dresses its home
  /// screen. The trailer will play in this same frame later; the space is laid out for
  /// it now.
  @ViewBuilder
  private var backdrop: some View {
    ZStack(alignment: .topLeading) {
      Color.KinoPub.background

      if let card = card(for: backdropCard) {
        ProgressiveBlur(startPoint: 0.3, maxRadius: 60, layers: 5) {
          AsyncImage(url: URL(string: card.backdropImageURL)) { image in
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
          } placeholder: {
            Color.clear
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        // Keyed on the URL so a new backdrop is a new view, and the two cross-fade
        // instead of the same image view swapping its contents.
        .id(card.backdropImageURL)
        .transition(.opacity)

        scrim
      }
    }
    .animation(.easeInOut(duration: 0.45), value: backdropCard)
    .ignoresSafeArea()
  }

  /// The space the rows leave free at the top of the page, holding what the cards no
  /// longer say under themselves. The trailer will play in this same frame later.
  ///
  /// It is a link, not a label: 560 points of unfocusable space above the first row
  /// swallows every press of Up, and the tab bar above it becomes unreachable. Being
  /// focusable also earns its keep — Up from the first row lands here, and clicking
  /// opens the item, the way a Netflix hero does.
  @ViewBuilder
  private var previewZone: some View {
    if let card = card(for: backdropCard) {
      NavigationLink(value: navigationLinkProvider(card)) {
        preview(for: card)
      }
      .buttonStyle(PreviewButtonStyle())
      .id(card.id)
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.3), value: backdropCard)
    } else {
      Color.clear
        .frame(height: Self.previewHeight)
    }
  }

  private func preview(for card: MediaCard) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Spacer(minLength: 0)

      Text(card.title)
        .font(Self.previewTitleFont)
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(2)

      if let subtitle = card.subtitle, !subtitle.isEmpty, subtitle != card.title {
        Text(subtitle)
          .font(Self.previewSubtitleFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
      }

      HStack(spacing: 12) {
        if let rating = card.rating {
          RatingBadgeView(rating: rating)
        }
        if let meta = card.metaLine, !meta.isEmpty {
          Text(meta)
            .font(Self.previewMetaFont)
            .foregroundStyle(Color.KinoPub.subtitle)
            .lineLimit(1)
        }
      }

      if let overview = card.overview, !overview.isEmpty {
        Text(overview)
          .font(Self.previewOverviewFont)
          .foregroundStyle(Color.KinoPub.text.opacity(0.85))
          .lineLimit(3)
          .frame(maxWidth: Self.previewTextWidth, alignment: .leading)
      }
    }
    .frame(height: Self.previewHeight, alignment: .bottomLeading)
    .padding(.horizontal, Self.horizontalInset)
    .padding(.bottom, Self.previewBottomInset)
    // A shadow rather than a scrim: the artwork stays at full brightness and the type
    // still holds up over a pale frame.
    .shadow(color: .black.opacity(0.7), radius: 12, y: 2)
  }

  /// Light: enough to seat the rows on the artwork, not enough to hide it. The
  /// backdrop is meant to be seen — the blur toward the bottom does the work of
  /// keeping the lower rows readable.
  private var scrim: some View {
    LinearGradient(stops: [
      .init(color: Color.KinoPub.background.opacity(0.35), location: 0),
      .init(color: Color.KinoPub.background.opacity(0.65), location: 0.35),
      .init(color: Color.KinoPub.background.opacity(0.92), location: 0.7),
      .init(color: Color.KinoPub.background, location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

#endif

  @ViewBuilder
  private func section(for row: MediaRow) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      header(for: row)
        .padding(.horizontal, Self.horizontalInset)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
          ForEach(row.cards) { card in
            NavigationLink(value: navigationLinkProvider(card)) {
              MediaCardView(card: card, caption: Self.cardCaption)
            }
#if os(tvOS)
            // The native tvOS poster effect: rounded corners, drop shadow, and on focus a
            // lift, the caption sliding down, a specular highlight and a touch-surface tilt
            // — all from `.borderless`, no custom code. It applies to the *image*, so the
            // card's label is just that (overlays would each get their own highlight and
            // fragment the effect); see MediaCardView.
            .buttonStyle(.borderless)
#else
            .buttonStyle(MediaCardButtonStyle())
#endif
            .focused($focusedCard, equals: CardKey(row: row.id, card: card.id))
            .modifier(MediaCardContextMenuModifier(actions: contextMenuProvider?(card) ?? []))
          }
        }
        .padding(.horizontal, Self.horizontalInset)
        // Focus grows the card past its frame; without room the lift gets clipped.
        .padding(.vertical, Self.focusPadding)
      }
    }
    .onAppear { onRowAppear?(row) }
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
  /// Free space above the rows, for the focused item's artwork, name and plot — and,
  /// later, its trailer. A little over half the 1080-point screen, so the first row
  /// sits low and the second only peeks, the way Netflix laid its home screen out.
  /// The focused card names itself in one line underneath — the hero preview that used to
  /// do it is off. Only on focus, over space kept reserved so the row doesn't reflow.
  static let cardCaption: MediaCardCaption = .onFocus

  static let previewHeight: CGFloat = 560
  static let previewBottomInset: CGFloat = 28
  static let previewTextWidth: CGFloat = 900
  static let previewTitleFont: Font = .system(size: 52, weight: .bold)
  static let previewSubtitleFont: Font = .system(size: 26, weight: .regular)
  static let previewMetaFont: Font = .system(size: 24, weight: .medium)
  static let previewOverviewFont: Font = .system(size: 24, weight: .regular)

  static let rowSpacing: CGFloat = 40
  static let cardSpacing: CGFloat = 36
  static let horizontalInset: CGFloat = 48
  static let focusPadding: CGFloat = 32
  static let headerFont: Font = .system(size: 32, weight: .semibold)
  static let countFont: Font = .system(size: 26, weight: .regular)
  static let chevronFont: Font = .system(size: 24, weight: .semibold)
#else
  /// No focus off TV, so no preview and no reserved room for one — the cards have to
  /// name themselves.
  static let cardCaption: MediaCardCaption = .always

  static let rowSpacing: CGFloat = 24
  static let cardSpacing: CGFloat = 16
  static let horizontalInset: CGFloat = 16
  static let focusPadding: CGFloat = 4
  static let headerFont: Font = .system(size: 22, weight: .semibold)
  static let countFont: Font = .system(size: 17, weight: .regular)
  static let chevronFont: Font = .system(size: 15, weight: .semibold)
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

/// The home preview's focus feedback. The block is the width of the screen, so a lift
/// like the cards get would read as the whole page jumping — it grows a little from its
/// bottom-left corner instead, where the text is anchored.
struct PreviewButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    Preview(configuration: configuration)
  }

  private struct Preview: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .environment(\.cardFocused, isFocused)
        .scaleEffect(isFocused ? 1.03 : 1, anchor: .bottomLeading)
        .opacity(configuration.isPressed ? 0.7 : 1)
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
