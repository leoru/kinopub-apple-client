//
//  Video.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Video: Codable, Hashable {
  public let id: Int
  public let title: String
  public let thumbnail: String
  public let duration: Int
  public let tracks: Int
  public let number: Int
  public let ac3: Int
  public let audios: [VideoAudio]
  public let watched: Int
  public let watching: EpisodeWatching
  public let subtitles: [Subtitle]
  public let files: [FileInfo]
}

public extension Video {
  /// Resume progress for this movie video (single source of truth for "watched / in progress").
  var watchProgress: WatchProgress {
    WatchProgress(position: Double(watching.time), duration: Double(duration))
  }
  /// "Finished" (watched to the credits).
  var isWatchedToEnd: Bool { watchProgress.isFinished }
  /// Single "watched" verdict: the explicit server flag OR watched-to-the-credits.
  var isWatched: Bool { watched > 0 || isWatchedToEnd }
}
