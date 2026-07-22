//
//  MediaScoresView.swift
//
//

import Foundation
import SwiftUI

/// A rating source's logo, template-rendered so it takes the surrounding tint.
/// Public because the detail page labels its score tiles with the same marks.
public struct MediaScoreLogo: View {

  public enum Source: String {
    case imdb
    case kinopoisk
  }

  private let source: Source
  private let height: CGFloat

  public init(_ source: Source, height: CGFloat) {
    self.source = source
    self.height = height
  }

  public var body: some View {
    Image(source.rawValue, bundle: .module)
      .renderingMode(.template)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: height)
  }
}

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
        score(logo: .imdb, value: imdbScore, imageHeight: Self.imdbHeight)
      }
      if let kinopoiskScore {
        score(logo: .kinopoisk, value: kinopoiskScore, imageHeight: Self.kinopoiskHeight)
      }
    }
  }

  /// Font and colour come from whatever this is dropped into. The scores sit inside
  /// a metadata line and have to read as part of it, not as a brighter, smaller badge
  /// pasted next to it.
  private func score(logo: MediaScoreLogo.Source, value: Double, imageHeight: CGFloat) -> some View {
    HStack(spacing: 6) {
      MediaScoreLogo(logo, height: imageHeight)
      Text(String(format: "%.1f", value))
        .monospacedDigit()
    }
  }

#if os(tvOS)
  static let groupSpacing: CGFloat = 24
  static let imdbHeight: CGFloat = 24
  static let kinopoiskHeight: CGFloat = 26
#else
  static let groupSpacing: CGFloat = 14
  static let imdbHeight: CGFloat = 14
  static let kinopoiskHeight: CGFloat = 15
#endif
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    MediaScoresView(imdb: 8.1, kinopoisk: 8.3)
    MediaScoresView(imdb: 7.4, kinopoisk: 0)
    MediaScoresView(imdb: nil, kinopoisk: 6.2)
  }
  .font(.subheadline)
  .foregroundStyle(Color.KinoPub.text)
  .padding()
  .background(Color.black)
}
