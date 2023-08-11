//
//  Trailer.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Trailer: Codable, Hashable {
  public let id: Int
  public let file: String
  public let url: String?
}
