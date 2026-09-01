//
//  NextPlayableEpisode.swift
//
//

import Foundation

/// The episode after `current`, in watching order: the next number in the same
/// season, else the first of the season after.
///
/// Pure model work — it feeds the tvOS system's Up Next panel (`AVContentProposal`),
/// which needs the answer when the stream is prepared and must never trigger a fetch.
public enum NextPlayableEpisode {

  /// - Parameters:
  ///   - current: the episode playing now. Matched by `id` — a media id unique per
  ///     episode — so an unstamped `seasonNumber` cannot misplace it.
  ///   - series: the cached series payload (a `LocalWatchProgressStore` snapshot).
  ///     Nil or seasonless means no proposal — never a guess.
  public static func after(_ current: Episode, in series: MediaItem?) -> Episode? {
    guard let seasons = series?.seasons else { return nil }
    // Reading order: season number, then episode number inside it.
    let flat: [(season: Int, episode: Episode)] = seasons
      .sorted { $0.number < $1.number }
      .flatMap { season in
        season.episodes
          .sorted { $0.number < $1.number }
          .map { (season.number, $0) }
      }
    guard let index = flat.firstIndex(where: { $0.episode.id == current.id }) else { return nil }
    let nextIndex = flat.index(after: index)
    guard nextIndex < flat.endIndex else { return nil }
    let next = flat[nextIndex]

    // A snapshot episode may predate stamping — and an unresolved `WatchingMetadata`
    // reports nothing to the server, so the hand-off fills what it knows. `Episode` is
    // a class: everything already holding the episode sees the stamp.
    if next.episode.mediaId == nil { next.episode.mediaId = series?.id }
    if next.episode.seasonNumber == nil { next.episode.seasonNumber = next.season }
    if next.episode.seriesTitle == nil { next.episode.seriesTitle = series?.localizedTitle }
    return next.episode
  }
}
