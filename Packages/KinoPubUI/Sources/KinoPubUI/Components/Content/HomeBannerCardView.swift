//
//  HomeBannerCardView.swift
//  KinoPubUI
//
//  Contained 16:9 Home featured card: wide backdrop, inset vertical poster,
//  titles + ratings. No CTAs for v1. Static art only — ProgressiveBlur is OK.
//

import SwiftUI

/// One contained featured banner for the Home shelf.
public struct HomeBannerCardView: View {
  private let card: MediaCard

  public init(card: MediaCard) {
    self.card = card
  }

  public var body: some View {
    Color.clear
      .aspectRatio(CardAspect.landscape.ratio, contentMode: .fit)
      .overlay {
        GeometryReader { geo in
          content(in: geo.size)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
  }

  private func content(in size: CGSize) -> some View {
    let posterHeight = min(size.height * 0.72, size.height - Self.contentPadding * 2)

    return ZStack(alignment: .bottomLeading) {
      backdrop

      ProgressiveBlur(startPoint: 0.42, maxRadius: 36)

      LinearGradient(
        stops: [
          .init(color: .clear, location: 0.35),
          .init(color: .black.opacity(0.45), location: 0.72),
          .init(color: .black.opacity(0.7), location: 1)
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      HStack(alignment: .bottom, spacing: Self.infoSpacing) {
        poster(height: posterHeight)

        VStack(alignment: .leading, spacing: Self.titleSpacing) {
          Text(card.title)
            .font(Self.titleFont)
            .foregroundStyle(.white)
            .lineLimit(2)
            .shadow(color: .black.opacity(0.55), radius: 6, y: 1)

          if let subtitle = card.subtitle, !subtitle.isEmpty, subtitle != card.title {
            Text(subtitle)
              .font(Self.subtitleFont)
              .foregroundStyle(.white.opacity(0.85))
              .lineLimit(1)
              .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
          }

          if card.imdbRating != nil || card.kinopoiskRating != nil {
            MediaScoresView(imdb: card.imdbRating, kinopoisk: card.kinopoiskRating)
              .font(Self.scoreFont)
              .foregroundStyle(.white.opacity(0.92))
          } else if let rating = card.rating {
            RatingBadgeView(rating: rating)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(Self.contentPadding)
    }
  }

  private var backdrop: some View {
    AsyncImage(url: URL(string: card.backdropImageURL)) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      default:
        Color.KinoPub.placeholder
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
  }

  private func poster(height: CGFloat) -> some View {
    AsyncImage(url: URL(string: card.posterURL)) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      default:
        Color.KinoPub.placeholder
      }
    }
    .aspectRatio(CardAspect.poster.ratio, contentMode: .fit)
    .frame(height: height)
    .clipShape(RoundedRectangle(cornerRadius: Self.posterCornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
  }

#if os(tvOS)
  static let cornerRadius: CGFloat = 20
  static let posterCornerRadius: CGFloat = 10
  static let contentPadding: CGFloat = 28
  static let infoSpacing: CGFloat = 24
  static let titleSpacing: CGFloat = 8
  static let titleFont: Font = .system(size: 34, weight: .bold)
  static let subtitleFont: Font = .system(size: 22, weight: .regular)
  static let scoreFont: Font = .system(size: 22, weight: .medium)
#else
  static let cornerRadius: CGFloat = 14
  static let posterCornerRadius: CGFloat = 8
  static let contentPadding: CGFloat = 14
  static let infoSpacing: CGFloat = 14
  static let titleSpacing: CGFloat = 4
  static let titleFont: Font = .system(size: 18, weight: .bold)
  static let subtitleFont: Font = .system(size: 13, weight: .regular)
  static let scoreFont: Font = .system(size: 13, weight: .medium)
#endif
}

#Preview {
  HomeBannerCardView(
    card: MediaCard(
      id: 1,
      posterURL: "",
      title: "Паук-Нуар",
      subtitle: "Spider-Noir",
      imdbRating: 7.8,
      kinopoiskRating: 7.5,
      backdropURL: ""
    )
  )
  .frame(width: 860)
  .padding()
  .background(Color.black)
}
