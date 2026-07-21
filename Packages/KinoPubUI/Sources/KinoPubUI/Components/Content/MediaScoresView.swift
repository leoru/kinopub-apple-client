//
//  MediaScoresView.swift
//
//

import Foundation
import SwiftUI

/// IMDb and Kinopoisk scores side by side. Unlike the poster badge this keeps them
/// separate — on a detail page there is room to show where each number came from.
public struct MediaScoresView: View {

  private let imdb: Double?
  private let kinopoisk: Double?

  public init(imdb: Double?, kinopoisk: Double?) {
    self.imdb = imdb
    self.kinopoisk = kinopoisk
  }

  /// The API sends 0 for "not rated".
  private var imdbScore: Double? { (imdb ?? 0) > 0 ? imdb : nil }
  private var kinopoiskScore: Double? { (kinopoisk ?? 0) > 0 ? kinopoisk : nil }

  public var body: some View {
    HStack(spacing: Self.groupSpacing) {
      if let imdbScore {
        score(image: "imdb", value: imdbScore, imageHeight: Self.imdbHeight)
      }
      if let kinopoiskScore {
        score(image: "kinopoisk", value: kinopoiskScore, imageHeight: Self.kinopoiskHeight)
      }
    }
  }

  private func score(image: String, value: Double, imageHeight: CGFloat) -> some View {
    HStack(spacing: 6) {
      Image(image, bundle: .module)
        .renderingMode(.template)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(height: imageHeight)
        .foregroundStyle(Color.KinoPub.text)
      Text(String(format: "%.1f", value))
        .font(Self.font)
        .monospacedDigit()
        .foregroundStyle(Color.KinoPub.text)
    }
  }

#if os(tvOS)
  static let groupSpacing: CGFloat = 24
  static let imdbHeight: CGFloat = 22
  static let kinopoiskHeight: CGFloat = 24
  static let font: Font = .system(size: 24, weight: .semibold)
#else
  static let groupSpacing: CGFloat = 14
  static let imdbHeight: CGFloat = 14
  static let kinopoiskHeight: CGFloat = 15
  static let font: Font = .system(size: 14, weight: .semibold)
#endif
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    MediaScoresView(imdb: 8.1, kinopoisk: 8.3)
    MediaScoresView(imdb: 7.4, kinopoisk: 0)
    MediaScoresView(imdb: nil, kinopoisk: 6.2)
  }
  .padding()
  .background(Color.black)
}
