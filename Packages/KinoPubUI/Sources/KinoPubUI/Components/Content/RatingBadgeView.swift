//
//  RatingBadgeView.swift
//
//

import Foundation
import SwiftUI

/// A single score combining the IMDb and Kinopoisk ratings.
public struct Rating {
  public let value: Double

  /// Averages the two sources when both are present, otherwise takes whichever one
  /// has a score. Zero means "not rated" in the API, so it counts as missing.
  public init?(imdb: Double?, kinopoisk: Double?) {
    let scores = [imdb, kinopoisk].compactMap { $0 }.filter { $0 > 0 }
    guard !scores.isEmpty else { return nil }
    value = scores.reduce(0, +) / Double(scores.count)
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
    case 5..<7: return .average
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
        .font(.system(size: Self.fontSize, weight: .bold))
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
  static let fontSize: CGFloat = 22
  static let horizontalPadding: CGFloat = 6
  static let verticalPadding: CGFloat = 2
  static let wingHeight: CGFloat = 22
#else
  static let fontSize: CGFloat = 13
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
        .font(.system(size: Self.fontSize, weight: .bold))
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
  static let fontSize: CGFloat = 44
  static let wingHeight: CGFloat = 36
  static let wingSpacing: CGFloat = 6
#else
  static let fontSize: CGFloat = 28
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
