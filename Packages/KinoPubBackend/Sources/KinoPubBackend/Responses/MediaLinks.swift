//
//  MediaLinks.swift
//
//  `GET /v1/items/media-links?mid=` — the playable files and subtitle tracks of one
//  media (an episode, or a film's video), fetched on their own so `/v1/items/<id>`
//  can be asked with `nolinks=1`. On a long-running series those links are most of
//  the details payload, and all but one episode's are thrown away.
//

import Foundation

public struct MediaLinks: Codable {

  public let files: [FileInfo]
  public let subtitles: [Subtitle]

  public init(files: [FileInfo], subtitles: [Subtitle] = []) {
    self.files = files
    self.subtitles = subtitles
  }

  private enum CodingKeys: String, CodingKey {
    case files
    case subtitles
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    files = (try? container.decode([FileInfo].self, forKey: .files)) ?? []
    subtitles = (try? container.decode([Subtitle].self, forKey: .subtitles)) ?? []
  }
}
