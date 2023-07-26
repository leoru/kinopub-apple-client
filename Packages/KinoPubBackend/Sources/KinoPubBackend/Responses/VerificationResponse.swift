//
//  VerificationResponse.swift
//
//
//  Created by Kirill Kunst on 17.07.2023.
//

import Foundation

public struct VerificationResponse: Codable {
  public let code: String
  public let userCode: String
  public let verificationUri: String
  public let expiresIn: Int
  public let interval: Int
  
  enum CodingKeys: String, CodingKey {
    case code
    case userCode = "user_code"
    case verificationUri = "verification_uri"
    case expiresIn = "expires_in"
    case interval
  }
}
