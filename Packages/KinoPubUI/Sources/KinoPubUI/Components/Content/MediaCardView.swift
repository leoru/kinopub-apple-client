//
//  MediaCardView.swift
//
//

import Foundation
import SwiftUI
import KinoPubBackend

/// Everything a poster card needs to draw itself, so rows can be built from any
/// endpoint's payload rather than only from a full `MediaItem`.
public struct MediaCard: Identifiable, Hashable, Codable {
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

  /// The title this card belongs to. For an episode card this is the series id;
  /// for a normal poster it matches `id`.
  public let itemID: Int
  /// Episode/video number for `/v1/watching/toggle`. Nil when the card is just a poster.
  public let video: Int?
  /// Season number for series episodes. Nil for films.
  public let season: Int?
  /// History media id for `/v1/history/clear-for-media`. Nil clears the whole item.
  public let mediaID: Int?
  /// Whether this video is already marked watched — drives the context-menu label.
  public let isWatched: Bool
  /// True for serials, so the context menu can say "Go to Show" rather than "Go to Movie".
  public let isSeries: Bool
  /// Title appears in `/v1/history` — context menu can offer Browse History.
  public let isInHistory: Bool
  /// Title is on the user's watchlist — context menu can offer Browse Watchlist.
  public let isInWatchlist: Bool

  public var isLandscape: Bool { landscapeImageURL != nil }

  /// What the focus backdrop draws: the wide artwork where the payload carried one,
  /// the card's own image otherwise.
  public var backdropImageURL: String {
    backdropURL ?? landscapeImageURL ?? posterURL
  }

  /// Whether a long-press can toggle watched for this card (needs a video target).
  public var canToggleWatched: Bool { video != nil }

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
              overlayLabel: String? = nil,
              itemID: Int? = nil,
              video: Int? = nil,
              season: Int? = nil,
              mediaID: Int? = nil,
              isWatched: Bool = false,
              isSeries: Bool = false,
              isInHistory: Bool = false,
              isInWatchlist: Bool = false) {
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
    self.itemID = itemID ?? id
    self.video = video
    self.season = season
    self.mediaID = mediaID
    self.isWatched = isWatched
    self.isSeries = isSeries
    self.isInHistory = isInHistory
    self.isInWatchlist = isInWatchlist
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
              overview: item.plot,
              isSeries: item.isSeries)
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

/// Poster or landscape card. Width comes from the parent (`containerRelativeFrame` /
/// grid column); height from `CardAspect`. Landscape cards follow the episode-rail
/// layout: play glyph + progress on the still, title / meta in the caption below —
/// no ⋯ overflow control on the card (long-press context menu only).
///
/// Behavioural identity: same focus animation, caption reveal, progress semantics,
/// watched treatment and existing badge slots; only aspect and which slots have
/// content differ. New badge slots (editorial awards etc.) wait on design (D10).
public struct MediaCardView: View {

  private let card: MediaCard
  private let caption: MediaCardCaption

  public init(card: MediaCard, caption: MediaCardCaption = .always) {
    self.card = card
    self.caption = caption
  }

  @Environment(\.isFocused) private var cardFocused

  private var aspect: CardAspect { card.isLandscape ? .landscape : .poster }

  private var imageURL: String {
    card.landscapeImageURL ?? card.posterURL
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: Metrics.cardCaptionSpacing) {
      artwork

      if caption != .none {
        captionBlock
      }
    }
  }

  // MARK: - Artwork

  @ViewBuilder
  private var artwork: some View {
    ZStack(alignment: .bottom) {
      stillImage

      if card.isLandscape {
        landscapeOverlays
      } else if let progress = card.progress {
#if !os(tvOS)
        progressBar(progress)
#endif
      }
    }
#if !os(tvOS)
    .overlay(alignment: .topLeading) {
      if !card.isLandscape, let rating = card.rating {
        RatingBadgeView(rating: rating)
          .padding(3)
      }
    }
    .overlay(alignment: .topTrailing) {
      if !card.isLandscape, let badge = card.badge {
        Text(badge)
          .font(.caption.weight(.bold))
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(Color.KinoPub.accent, in: Capsule())
          .foregroundStyle(.black)
          .shadow(radius: 4)
          .padding(3)
      }
    }
#endif
    .aspectRatio(aspect.ratio, contentMode: .fit)
    .frame(maxWidth: .infinity)
#if os(tvOS)
    // `.borderless` owns corners + focus lift. Landscape overlays are shapes /
    // symbols (not extra images) so the highlight stays one unit.
    .hoverEffect(.highlight)
#else
    .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
#endif
  }

  private var stillImage: some View {
    AsyncImage(url: URL(string: imageURL),
               transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
      if let image = phase.image {
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .clipped()
          .transition(.opacity)
      } else {
        Color.KinoPub.placeholder
#if os(tvOS)
          .clipShape(RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
#endif
      }
    }
  }

  /// Play glyph (bottom-leading) + progress pinned to the still's bottom edge.
  /// Labels live in the caption — nothing translucent over the picture.
  @ViewBuilder
  private var landscapeOverlays: some View {
    ZStack(alignment: .bottomLeading) {
      if let progress = card.progress {
        progressBar(progress)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      }

      Image(systemName: "play.fill")
        .font(TypeScale.cardMeta)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
        .padding(12)
    }
  }

  private func progressBar(_ progress: Double) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.black.opacity(0.55))
        Capsule()
          .fill(Color.KinoPub.accent)
          .frame(width: geometry.size.width * min(max(progress, 0), 1))
      }
    }
    .frame(height: Metrics.progressBarHeight)
  }

  // MARK: - Caption

  /// Hidden rather than absent while unfocused, so neighbouring cards keep their
  /// baselines and the row does not jump as focus travels along it.
  private var captionBlock: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(card.title)
        .lineLimit(card.isLandscape ? 2 : 1)
        .font(TypeScale.cardTitle)
        .foregroundStyle(Color.KinoPub.text)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)

      if card.isLandscape, let label = card.overlayLabel, !label.isEmpty {
        Text(label)
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
          .textCase(.uppercase)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .opacity(caption == .always || cardFocused ? 1 : 0)
    .animation(.easeOut(duration: 0.12), value: cardFocused)
  }

  // MARK: - Legacy metrics (call sites / placeholders until fully migrated)

  /// Fallback poster width when a caller still needs a concrete size (placeholders).
  public static var cardWidth: CGFloat {
    ShelfMetrics.posters(width: referenceWidth, typeSize: .large)
      .cardWidth(in: referenceWidth)
  }

  public static var posterHeight: CGFloat { cardWidth / CardAspect.poster.ratio }
  public static var landscapeWidth: CGFloat {
    ShelfMetrics.landscape(width: referenceWidth, typeSize: .large)
      .cardWidth(in: referenceWidth)
  }
  public static var landscapeHeight: CGFloat { landscapeWidth / CardAspect.landscape.ratio }
  public static var cornerRadius: CGFloat { Metrics.cardCornerRadius }
  public static var captionSpacing: CGFloat { Metrics.cardCaptionSpacing }
  public static var titleFont: Font { TypeScale.cardTitle }
  public static var subtitleFont: Font { TypeScale.cardSubtitle }

  private static var referenceWidth: CGFloat {
#if os(tvOS)
    1920
#elseif os(macOS)
    1100
#else
    390
#endif
  }
}

#Preview {
  MediaCardView(card: MediaCard(id: 1,
                                posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
                                title: "Стражи Галактики",
                                subtitle: "Guardians of the Galaxy",
                                imdbRating: 8.1,
                                kinopoiskRating: 8.3,
                                progress: 0.4,
                                badge: "2"))
  .frame(width: 260)
}
