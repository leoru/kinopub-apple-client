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
  public let watched: Int
  public let watching: EpisodeWatching
  public let subtitles: [Subtitle]
  public let files: [FileInfo]
  public var seasonNumber: Int?
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

extension Episode: PlayableItem {
  public var trailer: Trailer? { nil }
  public var metadata: WatchingMetadata {
    WatchingMetadata(id: id, video: number, season: seasonNumber)
  }
}
