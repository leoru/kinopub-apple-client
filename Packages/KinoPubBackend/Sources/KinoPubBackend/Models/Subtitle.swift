//
//  Subtitle.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Subtitle: Codable {
  public let lang: String
  public let shift: Int
  public let embed: Bool
  public let url: String
}
