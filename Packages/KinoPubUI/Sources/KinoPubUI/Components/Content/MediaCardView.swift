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
  public let isPlaceholder: Bool

  /// When set the card renders wide instead of as a poster — used by Continue
  /// Watching, where the artwork is an episode still.
  public let landscapeImageURL: String?
  /// Overlaid on a landscape card, e.g. "S2, E5 · 42 min".
  public let overlayLabel: String?

  public var isLandscape: Bool { landscapeImageURL != nil }

  public init(id: Int,
              posterURL: String,
              title: String,
              subtitle: String? = nil,
              imdbRating: Double? = nil,
              kinopoiskRating: Double? = nil,
              progress: Double? = nil,
              badge: String? = nil,
              isPlaceholder: Bool = false,
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
    self.isPlaceholder = isPlaceholder
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
              isPlaceholder: item.skeleton ?? false)
  }
}

/// A poster card sized for the platform, with a tvOS focus lift.
public struct MediaCardView: View {

  private let card: MediaCard

  public init(card: MediaCard) {
    self.card = card
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      poster
      titles
    }
    .frame(width: width)
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
      AsyncImage(url: URL(string: imageURL)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Color.KinoPub.skeleton
      }
      .frame(width: width, height: imageHeight)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

      if card.isLandscape {
        playbackFooter
      } else if let progress = card.progress {
        progressBar(progress)
      }
    }
    .overlay(alignment: .topLeading) {
      // Continue-watching cards lead with playback state; a score there is clutter.
      if !card.isPlaceholder, !card.isLandscape, let rating = card.rating {
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
    .skeleton(enabled: card.isPlaceholder,
              size: CGSize(width: width, height: imageHeight))
  }

  /// Play glyph, resume bar and episode label, laid over the bottom of the still —
  /// the shape the Apple TV app uses for Continue Watching.
  private var playbackFooter: some View {
    HStack(spacing: 10) {
      Image(systemName: "play.fill")
        .font(.system(size: Self.footerGlyphSize))
        .foregroundStyle(.white)

      Capsule()
        .fill(Color.white.opacity(0.35))
        .frame(width: Self.footerBarWidth, height: 4)
        .overlay(alignment: .leading) {
          Capsule()
            .fill(Color.white)
            .frame(width: Self.footerBarWidth * (card.progress ?? 0), height: 4)
        }

      if let label = card.overlayLabel {
        Text(label)
          .font(Self.footerFont)
          .foregroundStyle(.white)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .padding(.bottom, 12)
    .padding(.top, 28)
    .background(
      LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
    )
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

  private var titles: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(card.title)
        .lineLimit(1)
        .font(Self.titleFont)
        .foregroundStyle(Color.KinoPub.text)
      if let subtitle = card.subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .lineLimit(1)
          .font(Self.subtitleFont)
          .foregroundStyle(Color.KinoPub.subtitle)
      }
    }
    .skeleton(enabled: card.isPlaceholder, size: CGSize(width: width, height: 18))
  }

  // MARK: - Metrics

#if os(tvOS)
  static let cardWidth: CGFloat = 260
  static let posterHeight: CGFloat = 390
  static let landscapeWidth: CGFloat = 480
  static let landscapeHeight: CGFloat = 270
  static let footerFont: Font = .system(size: 22, weight: .semibold)
  static let footerGlyphSize: CGFloat = 20
  static let footerBarWidth: CGFloat = 70
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
