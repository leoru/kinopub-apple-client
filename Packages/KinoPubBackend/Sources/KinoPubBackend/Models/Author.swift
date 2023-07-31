//
//  Author.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct Author: Codable, Hashable {
  public let id: Int
  public let title: String?
  public let shortTitle: String?
}
