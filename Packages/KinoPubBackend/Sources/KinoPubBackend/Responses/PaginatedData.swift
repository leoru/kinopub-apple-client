//
//  PaginatedItemsResponse.swift
//
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

public struct PaginatedData<T: Codable>: Codable {

  public var items: [T]
  public var pagination: Pagination

  public static func mock(data: [T]) -> PaginatedData {
    return PaginatedData(items: data, pagination: Pagination(total: 0, current: 0, perpage: 0))
  }

}
