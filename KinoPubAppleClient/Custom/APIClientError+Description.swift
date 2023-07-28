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
  
}
