//
//  DeviceSettingsRequest.swift
//

import Foundation

public struct DeviceSettingsRequest: Endpoint {

  public var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String { "/v1/device/\(id)/settings" }
  public var method: String { "GET" }
  public var parameters: [String: Any]? { nil }
  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { false }
}
