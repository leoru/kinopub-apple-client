//
//  PlaybackButtonContent.swift
//

import Foundation

/// What the detail page's primary play control should show.
///
/// Prefer the resume case with a mini progress bar (same capsule as Continue
/// Watching cards). When a bar can't be drawn, fall back to a "Resume …" title.
public enum PlaybackButtonContent: Equatable {
  /// Mid-title: progress bar + "S1, E2 · 39 min" / "39 min", or "Resume …" without a bar.
  case resume(progress: Double, episodeLabel: String?, durationSeconds: Int)
  /// Fresh start, or the next unwatched episode after finishing a previous one.
  case play(episodeLabel: String?)
  case playAgain
}

public extension MediaItem {
  /// Season + episode the primary button would open — first unfinished, else the first.
  var primaryEpisode: (season: Season, episode: Episode)? {
    guard isSeries, let seasons, !seasons.isEmpty else { return nil }
    for season in seasons {
      if let episode = season.episodes.first(where: { !$0.isWatched }) {
        return (season, episode)
      }
    }
    if let season = seasons.first, let episode = season.episodes.first {
      return (season, episode)
    }
    return nil
  }

  var playbackButtonContent: PlaybackButtonContent {
    if playbackAction == .playAgain { return .playAgain }

    if isSeries {
      guard let (season, episode) = primaryEpisode else { return .play(episodeLabel: nil) }
      let label = "S\(season.number), E\(episode.number)"
      if let progress = Self.progress(watched: episode.watched,
                                      time: episode.watching.time,
                                      duration: episode.duration) {
        return .resume(progress: progress, episodeLabel: label, durationSeconds: episode.duration)
      }
      return .play(episodeLabel: label)
    }

    guard let video = videos?.first else { return .play(episodeLabel: nil) }
    if let progress = Self.progress(watched: video.watched,
                                    time: video.watching.time,
                                    duration: video.duration) {
      return .resume(progress: progress, episodeLabel: nil, durationSeconds: video.duration)
    }
    return .play(episodeLabel: nil)
  }

  private static func progress(watched: Int, time: Int, duration: Int) -> Double? {
    guard watched == 0 else { return nil }
    let watch = WatchProgress(position: Double(time), duration: Double(duration))
    return watch.resumeFraction
  }
}
