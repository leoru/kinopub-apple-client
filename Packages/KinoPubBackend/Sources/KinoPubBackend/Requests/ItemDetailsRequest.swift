//
//  ItemDetailsRequest.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation

public struct ItemDetailsRequest: Endpoint {
  
  private var id: String
  
  public init(id: String) {
    self.id = id
  }
  
  public var path: String {
    "/v1/items/\(id)"
  }
  
  public var method: String {
    "GET"
  }
  
  public var parameters: [String : Any]? {
    return nil
  }
  
  public var headers: [String : String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { false }
}
