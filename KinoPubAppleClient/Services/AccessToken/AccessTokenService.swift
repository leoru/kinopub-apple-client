//
//  AccessTokenService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation

protocol Token: Codable {
  var accessToken: String { get }
  var refreshToken: String { get }
  var expiresIn: Int { get }
}

protocol AccessTokenService {
  func set<T>(token: T) where T: Token
  func token<T>() -> T? where T: Token
}

protocol AccessTokenServiceProvider {
  var accessTokenService: AccessTokenService { get set }
}

struct AccessTokenServiceMock: AccessTokenService {

  func set<T>(token: T) where T: Token {

  }

  func token<T>() -> T? where T: Token {
    nil
  }

}
