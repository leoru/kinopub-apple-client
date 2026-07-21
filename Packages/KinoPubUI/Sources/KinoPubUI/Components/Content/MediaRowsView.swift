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
  public let cards: [MediaCard]

  public init(id: String, title: String, cards: [MediaCard]) {
    self.id = id
    self.title = title
    self.cards = cards
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
      Text(row.title)
        .font(Self.headerFont)
        .foregroundStyle(Color.KinoPub.text)
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

  // MARK: - Metrics

#if os(tvOS)
  static let rowSpacing: CGFloat = 40
  static let cardSpacing: CGFloat = 36
  static let horizontalInset: CGFloat = 48
  static let focusPadding: CGFloat = 32
  static let headerFont: Font = .system(size: 32, weight: .semibold)
#else
  static let rowSpacing: CGFloat = 24
  static let cardSpacing: CGFloat = 16
  static let horizontalInset: CGFloat = 16
  static let focusPadding: CGFloat = 4
  static let headerFont: Font = .system(size: 22, weight: .semibold)
#endif
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
        .scaleEffect(isFocused ? 1.08 : (configuration.isPressed ? 0.97 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: 18, y: 10)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
  }
}
