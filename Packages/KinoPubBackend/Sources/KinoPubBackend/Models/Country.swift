//
//  Country.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Country: Codable, Hashable {
  public let id: Int
  public let title: String
  
  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case title = "title"
  }
}
