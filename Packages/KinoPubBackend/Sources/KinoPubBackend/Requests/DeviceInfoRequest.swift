//
//  DeviceInfoRequest.swift
//

import Foundation

public struct DeviceInfoRequest: Endpoint {

  public init() {}

  public var path: String { "/v1/device/info" }
  public var method: String { "GET" }
  public var parameters: [String: Any]? { nil }
  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { false }
}
