//
//  EpisodeAudio.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct EpisodeAudio: Codable {
  public let id: Int
  public let index: Int
  public let codec: String
  public let channels: Int
  public let lang: String
  public let type: TypeClass?
  public let author: Author?
}
