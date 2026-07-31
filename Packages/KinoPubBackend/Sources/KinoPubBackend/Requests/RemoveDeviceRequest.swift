//
//  RemoveDeviceRequest.swift
//

import Foundation

/// Removes a device from the account — `POST /v1/device/<id>/remove`.
public struct RemoveDeviceRequest: Endpoint {

  public var id: Int

  public init(id: Int) {
    self.id = id
  }

  public var path: String { "/v1/device/\(id)/remove" }
  public var method: String { "POST" }
  public var parameters: [String: Any]? { nil }
  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { true }
}
