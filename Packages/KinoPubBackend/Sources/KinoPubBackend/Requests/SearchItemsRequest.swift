//
//  SearchItemsRequest.swift
//
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

public struct SearchItemsRequest: Endpoint {
  
  private var contentType: MediaType?
  private var page: Int?
  private var query: String?
  
  public init(contentType: MediaType?, page: Int? = nil, query: String? = nil) {
    self.contentType = contentType
    self.page = page
    self.query = query
  }
  
  public var path: String {
    "/v1/items/search"
  }
  
  public var method: String {
    "GET"
  }
  
  public var parameters: [String : Any]? {
    var params = [String : Any]()
    
    if let contentType = contentType {
      params["type"] = contentType.rawValue
    }
    
    if let page = page {
      params["page"] = "\(page)"
    }
    
    if let query = query {
      params["q"] = query
    }
    
    return params
  }
  
  public var headers: [String : String]? {
    nil
  }
  
  public var forceSendAsGetParams: Bool { false }
}
