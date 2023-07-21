//
//  TypeClass.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct TypeClass: Codable {
  public let id: Int
  public let title: String?
  public let shortTitle: String?
  
  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case title = "title"
    case shortTitle = "short_title"
  }
  
}
