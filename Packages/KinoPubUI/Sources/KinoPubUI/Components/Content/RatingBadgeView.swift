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
    case .awarded: return Color(red: 0.83, green: 0.68, blue: 0.22)
    case .good: return Color(red: 0.30, green: 0.72, blue: 0.40)
    case .average: return Color(white: 0.55)
    case .poor: return Color(red: 0.80, green: 0.25, blue: 0.25)
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
    HStack(spacing: 2) {
      if rating.tier.showsWings {
        wing(mirrored: false)
      }

      Text(rating.formatted)
        .font(.system(size: Self.fontSize, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(.white)

      if rating.tier.showsWings {
        wing(mirrored: true)
      }
    }
    .padding(.horizontal, Self.horizontalPadding)
    .padding(.vertical, Self.verticalPadding)
    .background(rating.tier.color, in: Capsule())
  }

  private func wing(mirrored: Bool) -> some View {
    Image("wing", bundle: .module)
      .renderingMode(.template)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: Self.wingHeight)
      .foregroundStyle(.white)
      .scaleEffect(x: mirrored ? -1 : 1)
  }

#if os(tvOS)
  static let fontSize: CGFloat = 22
  static let horizontalPadding: CGFloat = 10
  static let verticalPadding: CGFloat = 5
  static let wingHeight: CGFloat = 22
#else
  static let fontSize: CGFloat = 13
  static let horizontalPadding: CGFloat = 7
  static let verticalPadding: CGFloat = 3
  static let wingHeight: CGFloat = 14
#endif
}

#Preview {
  VStack(alignment: .leading, spacing: 12) {
    ForEach([9.1, 7.4, 6.2, 4.8], id: \.self) { score in
      if let rating = Rating(imdb: score, kinopoisk: score) {
        RatingBadgeView(rating: rating)
      }
    }
  }
  .padding()
  .background(Color.black)
}
