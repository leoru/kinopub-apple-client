//
//  MediaCardView.swift
//
//

import Foundation
import SwiftUI
import KinoPubBackend

/// Everything a poster card needs to draw itself, so rows can be built from any
/// endpoint's payload rather than only from a full `MediaItem`.
public struct MediaCard: Identifiable, Hashable {
  public let id: Int
  public let posterURL: String
  public let title: String
  public let subtitle: String?
  public let imdbRating: Double?
  public let kinopoiskRating: Double?

  /// The combined score shown on the poster, or nil when neither source rated it.
  public var rating: Rating? {
    Rating(imdb: imdbRating, kinopoisk: kinopoiskRating)
  }
  /// 0…1 for partially watched serials, nil when there is nothing to show.
  public let progress: Double?
  public let badge: String?

  /// Wide artwork for the page behind the card, shown while it holds focus. Nil
  /// falls back to whatever the card itself draws.
  public let backdropURL: String?

  /// "2025 · 1 h 55 min · Боевик" — shown in the focus preview, not on the card.
  public let metaLine: String?
  /// The plot, for the focus preview.
  public let overview: String?

  /// When set the card renders wide instead of as a poster — used by Continue
  /// Watching, where the artwork is an episode still.
  public let landscapeImageURL: String?
  /// Overlaid on a landscape card, e.g. "S2, E5 · 42 min".
  public let overlayLabel: String?

  public var isLandscape: Bool { landscapeImageURL != nil }

  /// What the focus backdrop draws: the wide artwork where the payload carried one,
  /// the card's own image otherwise.
  public var backdropImageURL: String {
    backdropURL ?? landscapeImageURL ?? posterURL
  }

  public init(id: Int,
              posterURL: String,
              title: String,
              subtitle: String? = nil,
              imdbRating: Double? = nil,
              kinopoiskRating: Double? = nil,
              progress: Double? = nil,
              badge: String? = nil,
              backdropURL: String? = nil,
              metaLine: String? = nil,
              overview: String? = nil,
              landscapeImageURL: String? = nil,
              overlayLabel: String? = nil) {
    self.id = id
    self.posterURL = posterURL
    self.title = title
    self.subtitle = subtitle
    self.imdbRating = imdbRating
    self.kinopoiskRating = kinopoiskRating
    self.progress = progress
    self.badge = badge
    self.backdropURL = backdropURL
    self.metaLine = metaLine
    self.overview = overview
    self.landscapeImageURL = landscapeImageURL
    self.overlayLabel = overlayLabel
  }
}

public extension MediaCard {
  /// The standard mapping from a catalog item, so grids and rows draw the same card.
  init(_ item: MediaItem) {
    self.init(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              imdbRating: item.imdbRating,
              kinopoiskRating: item.kinopoiskRating,
              backdropURL: item.posters.wideURL ?? item.posters.big,
              metaLine: item.metadataLine,
              overview: item.plot)
  }
}

/// Where a card's name is drawn, if anywhere.
public enum MediaCardCaption {
  /// Never — the screen names the focused item somewhere else, as the home rows do
  /// in their preview.
  case none
  /// Only while the card holds focus, over space kept free for it so the grid does
  /// not shift as focus moves. What a grid with no preview of its own uses.
  case onFocus
  /// Always, for platforms with no focus at all.
  case always
}

/// A poster card sized for the platform, with a tvOS focus lift.
public struct MediaCardView: View {

  private let card: MediaCard
  private let caption: MediaCardCaption

  public init(card: MediaCard, caption: MediaCardCaption = .always) {
    self.card = card
    self.caption = caption
  }

  @Environment(\.cardFocused) private var cardFocused

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      poster

      if caption != .none {
        title
      }
    }
    .frame(width: width)
  }

  /// Hidden rather than absent while unfocused, so neighbouring cards keep their
  /// baselines and the row does not jump as focus travels along it.
  private var title: some View {
    Text(card.title)
      .lineLimit(1)
      .font(Self.titleFont)
      .foregroundStyle(Color.KinoPub.text)
      .opacity(caption == .always || cardFocused ? 1 : 0)
      .animation(.easeOut(duration: 0.12), value: cardFocused)
      .frame(width: width, alignment: .leading)
  }

  private var width: CGFloat {
    card.isLandscape ? Self.landscapeWidth : Self.cardWidth
  }

  private var imageHeight: CGFloat {
    card.isLandscape ? Self.landscapeHeight : Self.posterHeight
  }

  private var imageURL: String {
    card.landscapeImageURL ?? card.posterURL
  }

  private var poster: some View {
    ZStack(alignment: .bottom) {
      artwork

      if card.isLandscape {
        playbackFooter
      } else if let progress = card.progress {
        progressBar(progress)
      }
    }
    .overlay(alignment: .topLeading) {
      // Continue-watching cards lead with playback state; a score there is clutter.
      if !card.isLandscape, let rating = card.rating {
        RatingBadgeView(rating: rating)
          .padding(6)
      }
    }
    .overlay(alignment: .topTrailing) {
      if let badge = card.badge {
        Text(badge)
          .font(.caption.weight(.bold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.KinoPub.accent, in: Capsule())
          .foregroundStyle(.black)
          .padding(6)
      }
    }
  }

  @ViewBuilder
  private var artwork: some View {
    // Artwork fades up out of the placeholder tile rather than popping in — with no
    // skeletons left, this is what covers the gap while a poster downloads.
    let image = AsyncImage(url: URL(string: imageURL),
                           transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
      if let image = phase.image {
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: width, height: imageHeight)
          .transition(.opacity)
      } else {
        Color.KinoPub.placeholder
          .frame(width: width, height: imageHeight)
      }
    }

    Group {
      if card.isLandscape {
        // Blur only the bottom strip, where the playback footer sits, so the still
        // stays crisp above it. Beats a black fade — the artwork shows through.
        ProgressiveBlur(startPoint: 0.6, maxRadius: 24, layers: 4) { image }
      } else {
        image
      }
    }
    .frame(width: width, height: imageHeight)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  /// Play glyph, resume bar and episode label over the bottom of the still. The text
  /// is vibrant-secondary at rest and turns solid white on focus.
  private var playbackFooter: some View {
    HStack(spacing: 10) {
      Image(systemName: "play.fill")
        .font(.system(size: Self.footerGlyphSize))

      Capsule()
        .fill(.secondary)
        .frame(width: Self.footerBarWidth, height: 4)
        .overlay(alignment: .leading) {
          Capsule()
            .fill(cardFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: Self.footerBarWidth * (card.progress ?? 0), height: 4)
        }

      if let label = card.overlayLabel {
        Text(label)
          .font(Self.footerFont)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .foregroundStyle(cardFocused ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
    .animation(.easeOut(duration: 0.15), value: cardFocused)
    .padding(.horizontal, 14)
    .padding(.bottom, 12)
    .padding(.top, 28)
  }

  private func progressBar(_ progress: Double) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.black.opacity(0.55))
        Capsule()
          .fill(Color.KinoPub.accent)
          .frame(width: geometry.size.width * progress)
      }
    }
    .frame(height: 5)
    .padding(.horizontal, 8)
    .padding(.bottom, 8)
  }

  // MARK: - Metrics

#if os(tvOS)
  static let cardWidth: CGFloat = 200
  static let posterHeight: CGFloat = 300
  static let landscapeWidth: CGFloat = 360
  static let landscapeHeight: CGFloat = 203
  static let footerFont: Font = .system(size: 18, weight: .semibold)
  static let footerGlyphSize: CGFloat = 16
  static let footerBarWidth: CGFloat = 56
  static let titleFont: Font = .system(size: 24, weight: .medium)
  static let subtitleFont: Font = .system(size: 20, weight: .regular)
#elseif os(macOS)
  static let cardWidth: CGFloat = 165
  static let posterHeight: CGFloat = 250
  static let landscapeWidth: CGFloat = 300
  static let landscapeHeight: CGFloat = 169
  static let footerFont: Font = .system(size: 13, weight: .semibold)
  static let footerGlyphSize: CGFloat = 12
  static let footerBarWidth: CGFloat = 44
  static let titleFont: Font = .system(size: 16, weight: .medium)
  static let subtitleFont: Font = .system(size: 14, weight: .regular)
#else
  static let cardWidth: CGFloat = 140
  static let posterHeight: CGFloat = 210
  static let landscapeWidth: CGFloat = 260
  static let landscapeHeight: CGFloat = 146
  static let footerFont: Font = .system(size: 12, weight: .semibold)
  static let footerGlyphSize: CGFloat = 11
  static let footerBarWidth: CGFloat = 40
  static let titleFont: Font = .system(size: 15, weight: .medium)
  static let subtitleFont: Font = .system(size: 13, weight: .regular)
#endif
}

#Preview {
  MediaCardView(card: MediaCard(id: 1,
                                posterURL: "",
                                title: "Стражи Галактики",
                                subtitle: "Guardians of the Galaxy",
                                imdbRating: 8.1,
                                kinopoiskRating: 8.3,
                                progress: 0.4,
                                badge: "2"))
}
