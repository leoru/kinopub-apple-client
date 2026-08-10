//
//  MediaScores.swift
//
//  UI-facing catalogue scores. Not the API DTO (`MediaItem`) and not the
//  aggregate (`Rating`) — just the two external sources the chrome draws.
//

import Foundation
import KinoPubBackend

/// IMDb + Kinopoisk numbers the UI is allowed to see. Map from `MediaItem` (or any
/// other payload) once at the boundary; views take this, not four loose optionals.
public struct MediaScores: Hashable, Codable, Sendable {

  public let imdb: Double?
  public let imdbVotes: Int?
  public let kinopoisk: Double?
  public let kinopoiskVotes: Int?

  public static let empty = MediaScores()

  public init(
    imdb: Double? = nil,
    imdbVotes: Int? = nil,
    kinopoisk: Double? = nil,
    kinopoiskVotes: Int? = nil
  ) {
    self.imdb = imdb
    self.imdbVotes = imdbVotes
    self.kinopoisk = kinopoisk
    self.kinopoiskVotes = kinopoiskVotes
  }

  public init(_ item: MediaItem) {
    self.init(
      imdb: item.imdbRating,
      imdbVotes: item.imdbVotes,
      kinopoisk: item.kinopoiskRating,
      kinopoiskVotes: item.kinopoiskVotes
    )
  }

  /// The API sends 0 for "not rated".
  public var imdbScore: Double? { Self.rated(imdb) }
  public var kinopoiskScore: Double? { Self.rated(kinopoisk) }

  public var hasDisplayableScore: Bool {
    imdbScore != nil || kinopoiskScore != nil
  }

  /// Vote counts that are actually present (> 0).
  public var totalVotes: Int {
    [imdbVotes, kinopoiskVotes]
      .compactMap { $0 }
      .filter { $0 > 0 }
      .reduce(0, +)
  }

  /// Our weighted aggregate, or nil when neither source rated the title.
  public var aggregate: Rating? { Rating(scores: self) }

  /// Keep one source for the card's rating-source preference.
  public func selecting(_ source: MediaCardRatingSource) -> MediaScores {
    switch source {
    case .combined:
      return self
    case .imdb:
      return MediaScores(imdb: imdb, imdbVotes: imdbVotes)
    case .kinopoisk:
      return MediaScores(kinopoisk: kinopoisk, kinopoiskVotes: kinopoiskVotes)
    }
  }

  private static func rated(_ value: Double?) -> Double? {
    (value ?? 0) > 0 ? value : nil
  }
}
