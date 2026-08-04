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
