//
//  MediaScoresView.swift
//
//

import Foundation
import SwiftUI

/// A rating source's logo. Template for tinted metadata lines; colour assets for
/// the detail score tiles.
public struct MediaScoreLogo: View {

  public enum Source: String {
    case imdb
    case kinopoisk

    fileprivate var colorAssetName: String {
      switch self {
      case .imdb: return "imdb_lol"
      case .kinopoisk: return "kinopoisk_lol"
      }
    }
  }

  public enum Style {
    /// Single-colour glyph that takes the surrounding foreground.
    case template
    /// Full-colour brand mark from the asset catalogue.
    case color
  }

  private let source: Source
  private let height: CGFloat
  private let style: Style

  public init(_ source: Source, height: CGFloat, style: Style = .color) {
    self.source = source
    self.height = height
    self.style = style
  }

  public var body: some View {
    Image(style == .color ? source.colorAssetName : source.rawValue, bundle: .module)
      .renderingMode(style == .color ? .original : .template)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(height: height)
  }
}

/// IMDb and Kinopoisk scores side by side. Unlike the poster badge this keeps them
/// separate — on a detail page there is room to show where each number came from.
public struct MediaScoresView: View {

  private let scores: MediaScores

  public init(_ scores: MediaScores) {
    self.scores = scores
  }

  /// Convenience for previews / call sites that still pass loose numbers.
  public init(
    imdb: Double?,
    kinopoisk: Double?,
    imdbVotes: Int? = nil,
    kinopoiskVotes: Int? = nil
  ) {
    self.init(MediaScores(
      imdb: imdb,
      imdbVotes: imdbVotes,
      kinopoisk: kinopoisk,
      kinopoiskVotes: kinopoiskVotes
    ))
  }

  public var body: some View {
    HStack(spacing: Self.groupSpacing) {
      if let value = scores.imdbScore {
        score(logo: .imdb, value: value, imageHeight: Self.imdbHeight, votes: scores.imdbVotes)
      }
      if let value = scores.kinopoiskScore {
        score(
          logo: .kinopoisk,
          value: value,
          imageHeight: Self.kinopoiskHeight,
          votes: scores.kinopoiskVotes
        )
      }
    }
  }

  /// Font and colour come from whatever this is dropped into. The scores sit inside
  /// a metadata line and have to read as part of it, not as a brighter, smaller badge
  /// pasted next to it.
  private func score(
    logo: MediaScoreLogo.Source,
    value: Double,
    imageHeight: CGFloat,
    votes: Int?
  ) -> some View {
    HStack(spacing: 7) {
      MediaScoreLogo(logo, height: imageHeight)
      Text(String(format: "%.1f", value))
        .fontDesign(.rounded)
        .fontWeight(.semibold)
      if let votes, votes > 0 {
        Text("(\(votes.formatted(.number.notation(.compactName))))")
          .font(.caption2)
          .fontWeight(.medium)
          .foregroundStyle(Color.KinoPub.subtitle)
      }
    }
  }

#if os(tvOS)
  static let groupSpacing: CGFloat = 24
  static let imdbHeight: CGFloat = 18
  static let kinopoiskHeight: CGFloat = 20
#else
  static let groupSpacing: CGFloat = 14
  static let imdbHeight: CGFloat = 14
  static let kinopoiskHeight: CGFloat = 15
#endif
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    MediaScoresView(MediaScores(imdb: 8.1, imdbVotes: 486_000, kinopoisk: 8.3, kinopoiskVotes: 92_000))
    MediaScoresView(imdb: 7.4, kinopoisk: 0)
    MediaScoresView(imdb: nil, kinopoisk: 6.2, kinopoiskVotes: 1_200)
  }
  .font(.body)
  .foregroundStyle(Color.KinoPub.text)
  .padding()
}
