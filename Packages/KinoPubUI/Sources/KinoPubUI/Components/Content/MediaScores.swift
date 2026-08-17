//
//  MediaScores.swift
//
//  UI-facing catalogue scores. Not the API DTO (`MediaItem`) and not the
//  aggregate (`Rating`) — just the external sources the chrome draws.
//

import Foundation
import KinoPubBackend

/// Which rating sources exist. The identity a weight, a logo and a tile all key off.
public enum RatingSourceID: String, Hashable, Codable, Sendable, CaseIterable {
  case imdb
  case kinopoisk
  case tmdb
  /// Us — the community thumbs, expressed on the same 0…10 scale as the rest.
  case kinopub
}

/// How much each source counts toward the aggregate.
///
/// **Everything is on and equal today.** The type exists so that the settings pane
/// this is heading for — tick the sources you trust, weigh one above another — changes
/// a stored value rather than the shape of the calculation, and so that "all sources,
/// equally" is written down as a default someone chose instead of being the absence of
/// a decision. A weight of `0` excludes the source outright.
public struct RatingWeights: Hashable, Codable, Sendable {
  public var weights: [RatingSourceID: Double]

  public init(weights: [RatingSourceID: Double] = [:]) {
    self.weights = weights
  }

  public static let `default` = RatingWeights()

  /// Unlisted sources count fully — a source added later is included until someone
  /// turns it off, which is the safer default for a number the user reads as "the".
  public func weight(for id: RatingSourceID) -> Double {
    max(0, weights[id] ?? 1)
  }

  public func isEnabled(_ id: RatingSourceID) -> Bool { weight(for: id) > 0 }
}

/// One source's contribution: its score on a 0…10 scale and how many people voted.
public struct RatingInput: Hashable, Sendable {
  public let id: RatingSourceID
  /// 0…10. Nil when the source has voters but no published score yet.
  public let score: Double?
  public let votes: Int?

  public init(id: RatingSourceID, score: Double?, votes: Int?) {
    self.id = id
    self.score = score
    self.votes = votes
  }
}

/// The external numbers the UI is allowed to see. Map from `MediaItem` (or any other
/// payload) once at the boundary; views take this, not eight loose optionals.
///
/// **Not every caller can fill it.** kino.pub's own payload carries IMDb and Kinopoisk
/// only, so a poster badge aggregates those two; TMDB's score arrives with enrichment
/// and the thumbs with the vote endpoint, so the detail page aggregates four. The
/// numbers can differ by a tenth between a card and the page it opens — the alternative
/// is plumbing enrichment through every shelf, which buys a decimal point.
public struct MediaScores: Hashable, Codable, Sendable {

  public let imdb: Double?
  public let imdbVotes: Int?
  public let kinopoisk: Double?
  public let kinopoiskVotes: Int?
  public let tmdb: Double?
  public let tmdbVotes: Int?
  /// kino.pub publishes no score, only thumbs.
  public let kinopubLikes: Int?
  public let kinopubDislikes: Int?

  public static let empty = MediaScores()

  public init(
    imdb: Double? = nil,
    imdbVotes: Int? = nil,
    kinopoisk: Double? = nil,
    kinopoiskVotes: Int? = nil,
    tmdb: Double? = nil,
    tmdbVotes: Int? = nil,
    kinopubLikes: Int? = nil,
    kinopubDislikes: Int? = nil
  ) {
    self.imdb = imdb
    self.imdbVotes = imdbVotes
    self.kinopoisk = kinopoisk
    self.kinopoiskVotes = kinopoiskVotes
    self.tmdb = tmdb
    self.tmdbVotes = tmdbVotes
    self.kinopubLikes = kinopubLikes
    self.kinopubDislikes = kinopubDislikes
  }

  public init(_ item: MediaItem) {
    self.init(
      imdb: item.imdbRating,
      imdbVotes: item.imdbVotes,
      kinopoisk: item.kinopoiskRating,
      kinopoiskVotes: item.kinopoiskVotes
    )
  }

  /// The same scores plus what only a detail page has: TMDB's audience score from
  /// enrichment, the community thumbs from the vote endpoint.
  public func adding(tmdb: Double? = nil,
                     tmdbVotes: Int? = nil,
                     kinopubLikes: Int? = nil,
                     kinopubDislikes: Int? = nil) -> MediaScores {
    MediaScores(
      imdb: imdb,
      imdbVotes: imdbVotes,
      kinopoisk: kinopoisk,
      kinopoiskVotes: kinopoiskVotes,
      tmdb: tmdb ?? self.tmdb,
      tmdbVotes: tmdbVotes ?? self.tmdbVotes,
      kinopubLikes: kinopubLikes ?? self.kinopubLikes,
      kinopubDislikes: kinopubDislikes ?? self.kinopubDislikes
    )
  }

  /// The API sends 0 for "not rated".
  public var imdbScore: Double? { Self.rated(imdb) }
  public var kinopoiskScore: Double? { Self.rated(kinopoisk) }
  public var tmdbScore: Double? { Self.rated(tmdb) }

  /// The share that liked it, on the 0…10 scale everything else uses.
  ///
  /// A thumbs system runs high — most titles land well above where their star ratings
  /// sit — but the aggregate weighs by turnout, and kino.pub's few hundred voters next
  /// to IMDb's hundreds of thousands move the number by a hair. That is the intended
  /// behaviour, not an oversight to correct with a fudge factor.
  public var kinopubScore: Double? {
    guard let votes = kinopubVotes, votes > 0, let likes = kinopubLikes else { return nil }
    return Double(likes) / Double(votes) * 10
  }

  public var kinopubVotes: Int? {
    let total = max(0, kinopubLikes ?? 0) + max(0, kinopubDislikes ?? 0)
    return total > 0 ? total : nil
  }

  public var hasDisplayableScore: Bool {
    imdbScore != nil || kinopoiskScore != nil
  }

  /// Every source, in one place, so a new one is added once.
  public var inputs: [RatingInput] {
    [
      RatingInput(id: .imdb, score: imdbScore, votes: imdbVotes),
      RatingInput(id: .kinopoisk, score: kinopoiskScore, votes: kinopoiskVotes),
      RatingInput(id: .tmdb, score: tmdbScore, votes: tmdbVotes),
      RatingInput(id: .kinopub, score: kinopubScore, votes: kinopubVotes)
    ]
  }

  /// Vote counts that are actually present (> 0).
  public var totalVotes: Int {
    inputs.compactMap(\.votes).filter { $0 > 0 }.reduce(0, +)
  }

  /// Our weighted aggregate, or nil when no enabled source rated the title.
  public var aggregate: Rating? { Rating(scores: self) }

  public func aggregate(weights: RatingWeights) -> Rating? {
    Rating(scores: self, weights: weights)
  }

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
