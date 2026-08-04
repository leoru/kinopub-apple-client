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
  case invalidGrant = "invalid_grant"
  case slowDown = "slow_down"
  case unauthorized = "unauthorized"
}

public struct BackendError: Error, Codable {
  /// Present on some kino.pub JSON envelopes; OAuth2 error bodies omit it.
  public var status: Int
  public var errorCode: BackendErrorCode
  public var errorDescription: String?

  private enum CodingKeys: String, CodingKey {
    case status
    case errorCode = "error"
    case errorDescription = "error_description"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // OAuth2 token errors are `{ "error": "invalid_grant", "error_description": "…" }`
    // with no `status`. Requiring it made refresh 400s decode as AccessToken failures
    // and get treated as transient network blips instead of a dead session.
    status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 0
    errorCode = try container.decode(BackendErrorCode.self, forKey: .errorCode)
    errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
  }
}
