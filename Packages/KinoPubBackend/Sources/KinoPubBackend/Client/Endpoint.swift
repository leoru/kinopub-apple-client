//
//  Endpoint.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public protocol Endpoint {
  var path: String { get }
  var method: String { get }
  var headers: [String: String]? { get }
  var parameters: [String: Any]? { get }
  var forceSendAsGetParams: Bool { get }
}

extension Endpoint {
  var forceSendAsGetParams: Bool {
    return false
  }
}
