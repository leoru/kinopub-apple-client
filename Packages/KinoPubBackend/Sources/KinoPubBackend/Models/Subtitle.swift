//
//  Subtitle.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Subtitle: Codable, Hashable {
  public let lang: String
  public let shift: Int
  public let embed: Bool
  public let url: String

  public init(lang: String, shift: Int, embed: Bool, url: String) {
    self.lang = lang
    self.shift = shift
    self.embed = embed
    self.url = url
  }
}
