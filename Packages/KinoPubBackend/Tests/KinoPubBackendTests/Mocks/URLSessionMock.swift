//
//  File.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation
@testable import KinoPubBackend

public class URLSessionMock: URLSessionProtocol {
  var data: Data?
  var response: URLResponse?
  var error: Error?
  
  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    if let error = error {
      throw error
    }
    
    return (data ?? Data(), response ?? URLResponse())
  }
}
