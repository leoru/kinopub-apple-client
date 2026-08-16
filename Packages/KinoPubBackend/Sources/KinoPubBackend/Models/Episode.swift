//
//  Episode.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class Episode: Codable, Hashable, Identifiable {
  
  public let id: Int
  public let title: String
  public let thumbnail: String
  public let duration: Int
  public let tracks: Int
  public let number: Int
  public let ac3: Int
  public let audios: [EpisodeAudio]
  /// Mutated after `/v1/watching/toggle` so the episode rail can flip its state
  /// without refetching the whole title.
  public var watched: Int
  public let watching: EpisodeWatching
  /// Both of these are empty when the details call asked for `nolinks=1`, and are filled
  /// in from `/v1/items/media-links` the first time this episode is actually played
  /// (`MediaLinksResolver`). `Episode` is a class, so the fill is visible to everything
  /// already holding the episode — the seasons rail, the player, the next-episode logic.
  public var subtitles: [Subtitle]
  public var files: [FileInfo]
  public var seasonNumber: Int?
  public var mediaId: Int?
  /// The series' own name. `Episode` arrives from the API with none of its parent's
  /// context, the same way `seasonNumber`/`mediaId` do — callers that already hold the
  /// series fill it in once they hand the episode to the player, so the transport bar's
  /// title line can read "Breaking Bad" instead of just the episode's own title.
  public var seriesTitle: String?

  public var fixedTitle: String {
    if title.isEmpty {
      return "Серия \(number)"
    }
    return title
  }
  
  public init(id: Int, title: String, thumbnail: String, duration: Int, tracks: Int, number: Int, ac3: Int, audios: [EpisodeAudio], watched: Int, watching: EpisodeWatching, subtitles: [Subtitle], files: [FileInfo]) {
    self.id = id
    self.title = title
    self.thumbnail = thumbnail
    self.duration = duration
    self.tracks = tracks
    self.number = number
    self.ac3 = ac3
    self.audios = audios
    self.watched = watched
    self.watching = watching
    self.subtitles = subtitles
    self.files = files
  }
  
  public static func == (lhs: Episode, rhs: Episode) -> Bool {
    lhs.id == rhs.id
  }
  
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public extension Episode {
  /// Resume progress for this episode (single source of truth for "watched / in progress").
  var watchProgress: WatchProgress {
    WatchProgress(position: Double(watching.time), duration: Double(duration))
  }
  /// "Finished" (watched to the credits) — so Continue offers the next episode, not this one's tail.
  var isWatchedToEnd: Bool { watchProgress.isFinished }
  /// Single "watched" verdict: the explicit server flag OR watched-to-the-credits.
  var isWatched: Bool { watched > 0 || isWatchedToEnd }
}

extension Episode: PlayableItem {
  public var trailer: Trailer? { nil }
  public var metadata: WatchingMetadata {
    WatchingMetadata(id: mediaId ?? id, video: number, season: seasonNumber)
  }
  // `subtitles` already declared on Episode

  public var audioTracks: [AudioTrackInfo] {
    AudioTracks.catalog(audios)
  }
}
