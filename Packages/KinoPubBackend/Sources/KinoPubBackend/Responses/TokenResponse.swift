//
//  TokenResponse.swift
//  
//
//  Created by Kirill Kunst on 17.07.2023.
//

import Foundation

public struct TokenResponse: Codable {
  public let accessToken: String
  public let tokenType: String
  public let expiresIn: Int
  public let refreshToken: String
  
  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case tokenType = "token_type"
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
  }
}
