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

/// A poster card sized for the platform, with a tvOS focus lift.
public struct MediaCardView: View {

  private let card: MediaCard
  private let caption: MediaCardCaption

  public init(card: MediaCard, caption: MediaCardCaption = .always) {
    self.card = card
    self.caption = caption
  }

  /// Read straight from the focus system rather than a value a button style hands down,
  /// so the card responds the same under the native `.borderless` style (which gives the
  /// real system parallax) as it did under the old hand-rolled one.
  @Environment(\.isFocused) private var cardFocused

  public var body: some View {
    VStack(alignment: .center, spacing: Self.captionSpacing) {
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
      .multilineTextAlignment(.center)
      .frame(width: width, alignment: .center)
      .opacity(caption == .always || cardFocused ? 1 : 0)
      .animation(.easeOut(duration: 0.12), value: cardFocused)
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

#if os(tvOS)
  /// Apple's borderless recipe, verbatim: a plain sized image and nothing else. The
  /// `.borderless` button style gives it the rounded corners, the drop shadow, and on
  /// focus lifts and scales the *whole* image — the frame grows past its neighbours —
  /// then shows the specular highlight and tilts to the remote's touch surface. We add no
  /// clip, shape or shadow of our own: a `clipShape`/`clipped` pins the frame, so the
  /// picture zooms inside a fixed rect and crops instead of the card growing. Overlays are
  /// gone for the same reason — each extra image layer gets its own highlight and the
  /// effect fragments. Score/progress can return as text in the caption if wanted.
  private var poster: some View {
    AsyncImage(url: URL(string: imageURL),
               transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
      if let image = phase.image {
        image
          .resizable()
          .transition(.opacity)
      } else {
        // Round the placeholder ourselves: `.borderless` rounds the loaded image, but a
        // bare fill tile would sit square until the poster arrives. Clip only this branch —
        // clipping the image too is what pinned the frame and broke the focus zoom.
        Color.KinoPub.placeholder
          .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
      }
    }
    .frame(width: width, height: imageHeight)
  }
#else
  /// The card off tvOS: artwork with the score, progress and — for a continue-watching
  /// still — the playback footer over it. There is no focus here, so overlays are free.
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
          .padding(3)
      }
    }
    .overlay(alignment: .topTrailing) {
      if let badge = card.badge {
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
    .frame(width: width, height: imageHeight)
    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
  }
#endif

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
#if !os(tvOS)
      if card.isLandscape {
        // Blur only the bottom strip, where the playback footer sits, so the still
        // stays crisp above it. Beats a black fade — the artwork shows through.
        ProgressiveBlur(startPoint: 0.6, maxRadius: 24, layers: 4) { image }
      } else {
        image
      }
#else
      // No footer on tvOS, so no strip to blur — the bare still.
      image
#endif
    }
    // The `.fill` overflow and the rounding both belong to the card as a whole now, so the
    // clip lives on `poster`, not here — see the note there.
    .frame(width: width, height: imageHeight)
//    .clipped()
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
        Capsule().fill(Color.black.opacity(0.65))
        Capsule()
          .fill(Color.KinoPub.accent)
          .frame(width: geometry.size.width * progress)
      }
    }
    .frame(height: 8)
    .padding(.horizontal, 10)
    .padding(.bottom, 10)
  }

  // MARK: - Metrics

#if os(tvOS)
  static let cornerRadius: CGFloat = 14
  /// Room under the poster so the focused card, which `.borderless` scales up, clears its
  /// caption instead of sitting right on top of it.
  static let captionSpacing: CGFloat = 20
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
  static let cornerRadius: CGFloat = 14
  static let captionSpacing: CGFloat = 6
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
  static let cornerRadius: CGFloat = 14
  static let captionSpacing: CGFloat = 6
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
                                posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
                                title: "Стражи Галактики",
                                subtitle: "Guardians of the Galaxy",
                                imdbRating: 8.1,
                                kinopoiskRating: 8.3,
                                progress: 0.4,
                                badge: "2"))
}
