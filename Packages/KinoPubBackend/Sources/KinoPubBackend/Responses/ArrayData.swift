//
//  ArrayData.swift
//
//
//  Created by Kirill Kunst on 6.08.2023.
//

import Foundation

public struct ArrayData<T: Codable>: Codable {
  
  public var items: [T]
  
  public static func mock(data: [T]) -> ArrayData {
    return ArrayData(items: data)
  }
  
}
