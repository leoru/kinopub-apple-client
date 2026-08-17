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

  /// - Parameters:
  ///   - local: the play head this device remembers, and whether it ran to the credits.
  ///   - history: the newest `/v1/history` row for this title, same question.
  ///   - watchedCount: `/v1/watching/serials`' count of watched episodes in the series.
  ///   - total: how many episodes it lists.
  ///
  /// Order of trust: an episode someone is in the middle of beats a count, and a count
  /// beats "the one after whatever history mentioned last" — the count is the server's
  /// own answer and survives episodes watched on another device.
  public static func forSeries(
    local: (season: Int?, episode: Int?, isFinished: Bool)?,
    history: (season: Int?, episode: Int?, isFinished: Bool)?,
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
    if let watchedCount, watchedCount > 0 {
      let next = watchedCount + 1
      if let total, next > total { return .nothingLeft }
      return ContinueWatchingEpisode(season: season, episode: next, isResuming: false)
    }
    // No count to go by: step past whatever was last seen. Better than offering it
    // again, and the detail page corrects the season if the step crossed one.
    if let last = history?.episode ?? local?.episode {
      let next = last + 1
      if let total, next > total { return .nothingLeft }
      return ContinueWatchingEpisode(season: season, episode: next, isResuming: false)
    }
    return ContinueWatchingEpisode(season: season, episode: nil, isResuming: false)
  }
}
