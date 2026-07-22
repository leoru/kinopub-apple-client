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
  /// Draws the title as a skeleton, for rows whose name has not arrived yet.
  public let isPlaceholder: Bool

  public init(id: String,
              title: String,
              count: String? = nil,
              cards: [MediaCard],
              destination: (any Hashable)? = nil,
              isPlaceholder: Bool = false) {
    self.id = id
    self.title = title
    self.count = count
    self.cards = cards
    self.destination = destination
    self.isPlaceholder = isPlaceholder
  }
}

/// The home layout: stacked rows of artwork, the way tvOS apps present a catalog.
public struct MediaRowsView: View {

  private let rows: [MediaRow]
  private let navigationLinkProvider: (MediaCard) -> any Hashable
  private let onRowAppear: ((MediaRow) -> Void)?

  public init(rows: [MediaRow],
              navigationLinkProvider: @escaping (MediaCard) -> any Hashable,
              onRowAppear: ((MediaRow) -> Void)? = nil) {
    self.rows = rows
    self.navigationLinkProvider = navigationLinkProvider
    self.onRowAppear = onRowAppear
  }

  public var body: some View {
    ScrollView(.vertical) {
      LazyVStack(alignment: .leading, spacing: Self.rowSpacing) {
        ForEach(rows) { row in
          section(for: row)
        }
      }
      .padding(.vertical, Self.rowSpacing)
    }
  }

  @ViewBuilder
  private func section(for row: MediaRow) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      header(for: row)
        .padding(.horizontal, Self.horizontalInset)

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
          ForEach(row.cards) { card in
            if card.isPlaceholder {
              // Skeleton cards carry index ids, not item ids — leaving them tappable
              // navigates straight to a 404.
              MediaCardView(card: card)
            } else {
              NavigationLink(value: navigationLinkProvider(card)) {
                MediaCardView(card: card)
              }
              .buttonStyle(MediaCardButtonStyle())
            }
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
    if let destination = row.destination, !row.isPlaceholder {
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
  static let rowSpacing: CGFloat = 40
  static let cardSpacing: CGFloat = 36
  static let horizontalInset: CGFloat = 48
  static let focusPadding: CGFloat = 32
  static let headerFont: Font = .system(size: 32, weight: .semibold)
  static let countFont: Font = .system(size: 26, weight: .regular)
  static let chevronFont: Font = .system(size: 24, weight: .semibold)
#else
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
    .skeleton(enabled: row.isPlaceholder, size: CGSize(width: 240, height: 24))
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

/// Lifts and highlights the focused card. tvOS's default styles would either wrap the
/// artwork in their own chrome or give no focus feedback at all.
struct MediaCardButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    Card(configuration: configuration)
  }

  private struct Card: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .environment(\.cardFocused, isFocused)
        .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.97 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: 18, y: 10)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
  }
}
