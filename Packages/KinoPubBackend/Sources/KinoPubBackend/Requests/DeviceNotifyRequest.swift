//
//  DeviceNotifyRequest.swift
//
//  POST /v1/device/notify — registers/updates the current device's name & specs so it
//  shows up properly (instead of "unknown") in the account's device list.
//

import Foundation

public struct DeviceNotifyRequest: Endpoint {

  public var title: String
  public var hardware: String
  public var software: String

  public init(title: String, hardware: String, software: String) {
    self.title = title
    self.hardware = hardware
    self.software = software
  }

  public var path: String {
    "/v1/device/notify"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    [
      "title": title,
      "hardware": hardware,
      "software": software
    ]
  }

  public var headers: [String: String]? {
    nil
  }

  // Send title/hardware/software in the form-urlencoded body. kino.pub records device *activity*
  // for a bare notify, but only applies the device name/specs when they arrive in the POST body.
  public var forceSendAsGetParams: Bool { false }
}
