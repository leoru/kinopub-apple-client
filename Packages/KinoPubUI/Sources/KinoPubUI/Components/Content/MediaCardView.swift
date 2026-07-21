//
//  MediaCardView.swift
//
//

import Foundation
import SwiftUI

/// Everything a poster card needs to draw itself, so rows can be built from any
/// endpoint's payload rather than only from a full `MediaItem`.
public struct MediaCard: Identifiable, Hashable {
  public let id: Int
  public let posterURL: String
  public let title: String
  public let subtitle: String?
  public let imdbRating: Double?
  public let kinopoiskRating: Double?
  /// 0…1 for partially watched serials, nil when there is nothing to show.
  public let progress: Double?
  public let badge: String?
  public let isPlaceholder: Bool

  public init(id: Int,
              posterURL: String,
              title: String,
              subtitle: String? = nil,
              imdbRating: Double? = nil,
              kinopoiskRating: Double? = nil,
              progress: Double? = nil,
              badge: String? = nil,
              isPlaceholder: Bool = false) {
    self.id = id
    self.posterURL = posterURL
    self.title = title
    self.subtitle = subtitle
    self.imdbRating = imdbRating
    self.kinopoiskRating = kinopoiskRating
    self.progress = progress
    self.badge = badge
    self.isPlaceholder = isPlaceholder
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
    .frame(width: Self.cardWidth)
  }

  private var poster: some View {
    ZStack(alignment: .bottom) {
      AsyncImage(url: URL(string: card.posterURL)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Color.KinoPub.skeleton
      }
      .frame(width: Self.cardWidth, height: Self.posterHeight)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

      if !card.isPlaceholder {
        ratings
      }

      if let progress = card.progress {
        progressBar(progress)
      }
    }
    .overlay(alignment: .topTrailing) {
      if let badge = card.badge {
        Text(badge)
          .font(.caption.weight(.bold))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.KinoPub.accent, in: Capsule())
          .foregroundStyle(.white)
          .padding(6)
      }
    }
    .skeleton(enabled: card.isPlaceholder,
              size: CGSize(width: Self.cardWidth, height: Self.posterHeight))
  }

  private var ratings: some View {
    VStack {
      Spacer()
      ContentItemRatingView(imdbScore: card.imdbRating, kinopoiskScore: card.kinopoiskRating)
        .padding(.bottom, card.progress == nil ? 8 : 16)
    }
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
    .skeleton(enabled: card.isPlaceholder, size: CGSize(width: Self.cardWidth, height: 18))
  }

  // MARK: - Metrics

#if os(tvOS)
  static let cardWidth: CGFloat = 260
  static let posterHeight: CGFloat = 390
  static let titleFont: Font = .system(size: 24, weight: .medium)
  static let subtitleFont: Font = .system(size: 20, weight: .regular)
#elseif os(macOS)
  static let cardWidth: CGFloat = 165
  static let posterHeight: CGFloat = 250
  static let titleFont: Font = .system(size: 16, weight: .medium)
  static let subtitleFont: Font = .system(size: 14, weight: .regular)
#else
  static let cardWidth: CGFloat = 140
  static let posterHeight: CGFloat = 210
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
