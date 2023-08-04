//
//  AccessTokenPlugin.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend

extension AccessToken: Token {}

struct AccessTokenPlugin: APIClientPlugin {

  private let accessTokenService: AccessTokenService

  init(accessTokenService: AccessTokenService) {
    self.accessTokenService = accessTokenService
  }

  func prepare(_ request: URLRequest) -> URLRequest {
    var request = request

    if let token: AccessToken = accessTokenService.token() {
      let authValue = "Bearer " + token.accessToken
      request.addValue(authValue, forHTTPHeaderField: "Authorization")
    }

    return request
  }

  func willSend(_ request: URLRequest) {

  }

  func didReceive(_ response: URLResponse, data: Data?) {

  }
}
