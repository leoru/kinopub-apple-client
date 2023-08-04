//
//  RefreshTokenRequest.swift
//
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

public struct RefreshTokenRequest: Endpoint {

  public var clientID: String
  public var clientSecret: String
  public var refreshToken: String

  public init(clientID: String, clientSecret: String, refreshToken: String) {
    self.clientID = clientID
    self.clientSecret = clientSecret
    self.refreshToken = refreshToken
  }

  public var path: String {
    "/oauth2/token"
  }

  public var method: String {
    "POST"
  }

  public var parameters: [String: Any]? {
    [
      "grant_type": "refresh_token",
      "client_id": clientID,
      "client_secret": clientSecret,
      "refresh_token": refreshToken
    ]
  }

  public var headers: [String: String]? {
    nil
  }

  public var forceSendAsGetParams: Bool { false }
}
