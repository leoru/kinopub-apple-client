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
  /// A host + prefix to use instead of the configured base URL, for the handful of
  /// methods that only exist on kino.pub's other API branch. Nil — the default — means
  /// the mirror the user is signed in to, which is where everything else lives.
  var baseURLOverride: URL? { get }
}

extension Endpoint {
  var forceSendAsGetParams: Bool {
    return false
  }

  public var baseURLOverride: URL? { nil }
}
