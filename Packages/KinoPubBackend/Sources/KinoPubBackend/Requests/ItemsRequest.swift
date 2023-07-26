//
//  ItemsRequest.swift
//
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

public struct ItemsRequest: Endpoint {
  
  public init() {}
  
  public var path: String {
    "/v1/items"
  }
  
  public var method: String {
    "GET"
  }
  
  public var parameters: [String : Any]? {
    nil
  }
  
  public var headers: [String : String]? {
    nil
  }
}