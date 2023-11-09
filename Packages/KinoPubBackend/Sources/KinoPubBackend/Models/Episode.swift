//
//  Episode.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Episode: Codable, Hashable, Identifiable {
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
  
  public var fixedTitle: String {
    if title.isEmpty {
      return "Серия \(number)"
    }
    return title
  }
}

extension Episode: PlayableItem {
  public var trailer: Trailer? { nil }
}
