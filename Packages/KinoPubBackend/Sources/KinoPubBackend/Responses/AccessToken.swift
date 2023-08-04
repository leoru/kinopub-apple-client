//
//  TokenResponse.swift
//  
//
//  Created by Kirill Kunst on 17.07.2023.
//

import Foundation

public struct AccessToken: Codable {
  public let accessToken: String
  public let refreshToken: String
  public let expiresIn: Int

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
  }
}
