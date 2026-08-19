//
//  ContinueWatchingEpisode.swift
//

import Foundation

/// Which episode Continue Watching should offer for a series, and whether that episode
/// is one the viewer is in the middle of.
///
/// 🔴 **The last episode in history is not the next one to watch.** The card used to
/// take its S/E straight from the newest history row, so a series whose last row was
/// "S1, E2, finished" offered E2 again — with E2's full runtime under it, as if it had
/// never been played. `watched: 1` on an episode means watched to the end.
public struct ContinueWatchingEpisode: Equatable, Sendable {

  public let season: Int?
  public let episode: Int?
  /// True when the viewer is **mid-episode**, which is the only case where a resume bar
  /// and a "N left" label mean anything. False when this is a fresh episode: the
  /// progress and duration on hand belong to the *previous* one and must not be drawn
  /// under this one.
  public let isResuming: Bool

  public init(season: Int?, episode: Int?, isResuming: Bool) {
    self.season = season
    self.episode = episode
    self.isResuming = isResuming
  }

  /// Nothing left to offer — every episode the server knows about has been watched.
  public static let nothingLeft = ContinueWatchingEpisode(season: nil, episode: nil,
                                                          isResuming: false)

  public var hasEpisode: Bool { episode != nil }

  /// Overlay on a landscape Continue Watching card — the episode the card offers,
  /// not whichever history row happened to be newest.
  public static func overlayLabel(season: Int?, episode: Int?) -> String? {
    guard let episode else { return nil }
    guard let season, season > 0 else { return "E\(episode)" }
    return "S\(season), E\(episode)"
  }

  /// - Parameters:
  ///   - local: the play head this device remembers, and whether it ran to the credits.
  ///   - history: the newest `/v1/history` row for this title, same question.
  ///   - finishedInSeason: **every** episode of that season history says was watched to
  ///     the end — not just the newest row.
  ///   - watchedCount: `/v1/watching/serials`' count of watched episodes in the series.
  ///   - total: how many episodes it lists.
  ///
  /// An episode someone is in the middle of wins outright. Otherwise the answer is one
  /// past **the furthest episode any source calls finished** — history rows are ordered
  /// by when they were played, not by episode number, so "the last row + 1" offered E3
  /// on a series whose E1–E4 were all watched. Taking the maximum also survives a
  /// truncated history: 20 rows deep, an old E1 may be gone while E4 is still there.
  public static func forSeries(
    local: (season: Int?, episode: Int?, isFinished: Bool)?,
    history: (season: Int?, episode: Int?, isFinished: Bool)?,
    finishedInSeason: Set<Int> = [],
    watchedCount: Int?,
    total: Int?
  ) -> ContinueWatchingEpisode {
    if let local, let episode = local.episode, !local.isFinished {
      return ContinueWatchingEpisode(season: local.season, episode: episode, isResuming: true)
    }
    if let history, let episode = history.episode, !history.isFinished {
      return ContinueWatchingEpisode(season: history.season, episode: episode, isResuming: true)
    }

    let season = history?.season ?? local?.season
    // Each source is a *lower bound* on how far the viewer got, so the furthest one
    // wins: the server count knows about other devices, history knows about episodes
    // the count has not caught up with yet.
    var reached = finishedInSeason.max() ?? 0
    if let watchedCount { reached = max(reached, watchedCount) }
    if let history, history.isFinished, let episode = history.episode {
      reached = max(reached, episode)
    }
    if let local, local.isFinished, let episode = local.episode {
      reached = max(reached, episode)
    }
    guard reached > 0 else {
      return ContinueWatchingEpisode(season: season, episode: nil, isResuming: false)
    }

    let next = reached + 1
    if let total, next > total { return .nothingLeft }
    return ContinueWatchingEpisode(season: season, episode: next, isResuming: false)
  }
}
