//
//  File.swift
//  
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public protocol URLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public class URLSessionImpl: URLSessionProtocol {
  let session: URLSession
  
  init(session: URLSession) {
    self.session = session
  }
  
  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await session.data(for: request)
  }
}
