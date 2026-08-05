//
//  BackendError.swift
//
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation

/// OAuth/kino.pub error codes. Unknown strings decode as `.unknown(raw)` rather than
/// failing the whole envelope — a token endpoint answering with a code we haven't
/// seen is still a rejected grant, never a decoding glitch.
public enum BackendErrorCode: Codable, Hashable, Sendable {
  case authorizationPending
  case invalidClient
  case invalidGrant
  case slowDown
  case unauthorized
  case unknown(String)

  public var rawValue: String {
    switch self {
    case .authorizationPending: return "authorization_pending"
    case .invalidClient: return "invalid_client"
    case .invalidGrant: return "invalid_grant"
    case .slowDown: return "slow_down"
    case .unauthorized: return "unauthorized"
    case .unknown(let raw): return raw
    }
  }

  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    switch raw {
    case "authorization_pending": self = .authorizationPending
    case "invalid_client": self = .invalidClient
    case "invalid_grant": self = .invalidGrant
    case "slow_down": self = .slowDown
    case "unauthorized": self = .unauthorized
    default: self = .unknown(raw)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
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
