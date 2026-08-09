//
//  RatingBadgeView.swift
//
//

import Foundation
import SwiftUI

/// Our own averaged score: the poster plaque, the hero pill, the detail "Rating"
/// tile, and the card Rating placement / source settings that drive them.
///
/// Off while the aggregate is being reworked — until then IMDb and Kinopoisk show
/// only under their own logos, never folded into one number. An off flag hides the
/// settings too, so nothing points at chrome that cannot appear.
public enum RatingFeature {
  public static let combinedEnabled = false
}

/// A single score combining the IMDb and Kinopoisk ratings.
public struct Rating {
  public let value: Double

  /// Combines the two sources, **weighted by how many people voted**. 6.0 from 4,867
  /// voters next to 1.0 from 7 is a 6.0 title, not the 3.5 a plain mean of the two
  /// numbers would print. A source that reports no count still counts, but as a single
  /// vote, so it can never outweigh a real audience. Zero means "not rated" in the API,
  /// so it counts as missing.
  public init?(imdb: Double?,
               imdbVotes: Int? = nil,
               kinopoisk: Double?,
               kinopoiskVotes: Int? = nil) {
    let sources = [(imdb ?? 0, imdbVotes ?? 0), (kinopoisk ?? 0, kinopoiskVotes ?? 0)]
      .filter { $0.0 > 0 }
      .map { (score: $0.0, weight: Double(max($0.1, 1))) }
    guard !sources.isEmpty else { return nil }
    let total = sources.reduce(0) { $0 + $1.weight }
    value = sources.reduce(0) { $0 + $1.score * $1.weight } / total
  }

  public enum Tier {
    case awarded   // 8.0+
    case good      // 7.0…8.0
    case average   // 6.0…7.0
    case poor      // below 6.0
  }

  /// The value as shown, to one decimal. Tiering off this rather than the raw average
  /// keeps the colour honest: a 7.95 that reads "8.0" gets the 8.0 treatment.
  public var rounded: Double {
    (value * 10).rounded() / 10
  }

  public var tier: Tier {
    switch rounded {
    case 8...: return .awarded
    case 7..<8: return .good
    case 6..<7: return .average
    default: return .poor
    }
  }

  public var formatted: String {
    String(format: "%.1f", rounded)
  }
}

public extension Rating.Tier {
  var color: Color {
    switch self {
    case .awarded: return Color.yellow
    case .good: return Color.green
    case .average: return Color.gray
    case .poor: return Color.red
    }
  }

  /// Only the top tier earns the laurel wings.
  var showsWings: Bool {
    self == .awarded
  }
}

/// Score plaque for the top-left corner of a poster.
public struct RatingBadgeView: View {

  private let rating: Rating

  public init(rating: Rating) {
    self.rating = rating
  }

  public var body: some View {
    HStack(spacing: 3) {
      if rating.tier.showsWings {
        wing(mirrored: false)
      }

      Text(rating.formatted)
        .font(TypeScale.ratingBadge)
        .foregroundStyle(rating.tier.showsWings ? .black : .white)

      if rating.tier.showsWings {
        wing(mirrored: true)
      }
    }
    .padding(.horizontal, rating.tier.showsWings ? Self.horizontalPadding / 2 : Self.horizontalPadding)
    .padding(.vertical, Self.verticalPadding)
    .background(rating.tier.color, in: Capsule())
  }

  private func wing(mirrored: Bool) -> some View {
    Image("wing", bundle: .module)
      .renderingMode(.template)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: Self.wingHeight)
      .foregroundStyle(.black)
      .scaleEffect(x: mirrored ? -1 : 1)
  }

#if os(tvOS)
  static let horizontalPadding: CGFloat = 6
  static let verticalPadding: CGFloat = 2
  static let wingHeight: CGFloat = 22
#else
  static let horizontalPadding: CGFloat = 6
  static let verticalPadding: CGFloat = 2
  static let wingHeight: CGFloat = 14
#endif
}

/// Large aggregate score for the detail ratings row: coloured digits and laurel
/// wings when the tier earns them — not the poster capsule.
public struct AggregateRatingLabel: View {

  private let rating: Rating

  public init(rating: Rating) {
    self.rating = rating
  }

  public var body: some View {
    HStack(spacing: Self.wingSpacing) {
      if rating.tier.showsWings {
        wing(mirrored: false)
      }

      Text(rating.formatted)
        .font(TypeScale.ratingAggregate)
        .monospacedDigit()
        .foregroundStyle(rating.tier.color)

      if rating.tier.showsWings {
        wing(mirrored: true)
      }
    }
  }

  private func wing(mirrored: Bool) -> some View {
    Image("wing", bundle: .module)
      .renderingMode(.template)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: Self.wingHeight)
      .foregroundStyle(rating.tier.color)
      .scaleEffect(x: mirrored ? -1 : 1)
  }

#if os(tvOS)
  static let wingHeight: CGFloat = 36
  static let wingSpacing: CGFloat = 6
#else
  static let wingHeight: CGFloat = 22
  static let wingSpacing: CGFloat = 4
#endif
}

#Preview {
  VStack(alignment: .leading, spacing: 12) {
    ForEach([9.1, 7.4, 6.2, 4.8], id: \.self) { score in
      if let rating = Rating(imdb: score, kinopoisk: score) {
        RatingBadgeView(rating: rating)
        AggregateRatingLabel(rating: rating)
      }
    }
  }
  .padding()
  .background(Color.black)
}
