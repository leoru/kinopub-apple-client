//
//  APIClientError.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public enum APIClientError: Error {
  case urlError
  case invalidUrlParams
  case networkError(Error)
  case decodingError(Error)
  /// Non-2xx HTTP response whose body was not a structured `BackendError` envelope.
  case httpStatus(Int, data: Data?)
}

public extension APIClientError {
  /// The credentials were refused: any 400/401 (a token endpoint's rejections are
  /// never transient), or a structured grant/auth error envelope — including codes
  /// we don't know (`.unknown`), which on a token endpoint still mean "rejected".
  /// Transport failures (timeout, offline, cancelled) are never auth rejections.
  var isAuthRejection: Bool {
    switch self {
    case .httpStatus(let code, _):
      return code == 400 || code == 401
    case .networkError(let error):
      guard let backendError = error as? BackendError else { return false }
      switch backendError.errorCode {
      case .invalidGrant, .invalidClient, .unauthorized, .unknown:
        return true
      case .authorizationPending, .slowDown:
        return false
      }
    case .urlError, .invalidUrlParams, .decodingError:
      return false
    }
  }
}
