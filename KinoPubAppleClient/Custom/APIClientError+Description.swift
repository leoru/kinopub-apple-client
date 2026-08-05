//
//  APIClientError+Description.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import KinoPubBackend

extension APIClientError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .urlError:
      return "Wrong URL"
    case .invalidUrlParams:
      return "Invalid URL params"
    case .decodingError(let error):
      return "Decoding issue: \(error)"
    case .networkError(let error):
      if let error = error as? BackendError {
        return error.errorDescription ?? error.localizedDescription
      }
      return "Networking issue: \(error)"
    case .httpStatus(let code, _):
      return "HTTP \(code)"
    }
  }

  var isAuthorizationPending: Bool {
    switch self {
    case .networkError(let error):
      if let backendError = error as? BackendError, backendError.errorCode == .authorizationPending {
        return true
      }
      break
    default: return false
    }
    return false
  }

  /// True only when the backend explicitly rejected the credentials: a 401 (token
  /// died — body shape doesn't matter) or a structured `invalid_grant`/`unauthorized`
  /// envelope. Transport failures — timeout, offline, cancelled — are not auth
  /// failures and must never log the user out.
  var isFatalAuthError: Bool {
    if case .httpStatus(let code, _) = self, code == 401 {
      return true
    }
    guard case .networkError(let error) = self, let backendError = error as? BackendError else {
      return false
    }
    switch backendError.errorCode {
    case .invalidGrant, .invalidClient, .unauthorized:
      return true
    case .authorizationPending, .slowDown:
      return false
    }
  }

  /// Cancelled requests are superseded by newer ones, not failed — no error UI for them.
  var isCancellation: Bool {
    guard case .networkError(let error) = self else { return false }
    return (error as? URLError)?.code == .cancelled
  }

  /// Short text for the error toast and unavailable-content views. Tells the truth
  /// about the cause: an expired session is not "check your connection".
  var userFacingMessage: String {
    switch self {
    case .networkError(let error):
      if let backendError = error as? BackendError {
        switch backendError.errorCode {
        case .invalidGrant, .unauthorized, .invalidClient:
          return "Your session has expired. Try again.".localized
        case .authorizationPending, .slowDown:
          break
        }
        return backendError.errorDescription ?? backendError.errorCode.rawValue
      }
      if error is URLError {
        return "Check your connection and try again.".localized
      }
      return error.localizedDescription
    case .httpStatus(let code, _):
      if code == 401 {
        return "Your session has expired. Try again.".localized
      }
      return "Request failed (\(code))"
    case .urlError, .invalidUrlParams, .decodingError:
      return description
    }
  }

}

extension Error {
  /// `APIClientError.userFacingMessage` when possible, the system's text otherwise —
  /// so call sites don't have to unwrap the error type themselves.
  var userFacingMessage: String {
    (self as? APIClientError)?.userFacingMessage ?? localizedDescription
  }
}
