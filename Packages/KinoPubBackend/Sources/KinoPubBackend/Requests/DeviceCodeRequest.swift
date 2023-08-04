//
//  DeviceCodeRequest.swift
//
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

public enum DeviceCodeGrantType: String {
  case deviceCode = "device_code"
  case deviceToken = "device_token"
}

public struct DeviceCodeRequest: Endpoint {

  public var grantType: DeviceCodeGrantType
  public var clientID: String
  public var clientSecret: String
  public var code: String?

  public init(grantType: DeviceCodeGrantType, clientID: String, clientSecret: String, code: String? = nil) {
    self.grantType = grantType
    self.clientID = clientID
    self.clientSecret = clientSecret
    self.code = code
  }

  public var path: String {
    "/oauth2/device"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    var params = [
      "grant_type": grantType.rawValue,
      "client_id": clientID,
      "client_secret": clientSecret
    ]

    if let code = code {
      params["code"] = code
    }

    return params
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool {
    return true
  }
}
