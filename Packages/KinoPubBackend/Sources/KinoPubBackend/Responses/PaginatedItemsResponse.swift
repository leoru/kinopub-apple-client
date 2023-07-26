//
//  PaginatedItemsResponse.swift
//
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

public struct PaginatedItemsResponse<T: Codable>: Codable {
  
  public var items: [T]
  public var pagination: Pagination
  
}
