//
//  File.swift
//  
//
//  Created by Kirill Kunst on 14.08.2023.
//

import Foundation

public struct CountriesRequest: Endpoint {

  public init() {}

  public var path: String {
    "/v1/countries"
  }

  public var method: String {
    "GET"
  }

  public var parameters: [String: Any]? {
    nil
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
