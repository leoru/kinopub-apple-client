//
//  BackendError.swift
//
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation

public enum BackendErrorCode: String, Codable {
  case authorizationPending = "authorization_pending"
  case invalidClient = "invalid_client"
  case unauthorized = "unauthorized"
}

public struct BackendError: Error, Codable {
  public var status: Int
  public var errorCode: BackendErrorCode
  public var errorDescription: String?

  private enum CodingKeys: String, CodingKey {
    case status
    case errorCode = "error"
    case errorDescription = "error_description"
  }
}
