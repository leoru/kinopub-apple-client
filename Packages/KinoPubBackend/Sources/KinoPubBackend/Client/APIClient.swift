//
//  APIClient.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class APIClient {
  private let session: URLSessionProtocol
  private let requestBuilder: RequestBuilder
  private let baseUrl: URL
  private var plugins: [APIClientPlugin]
  
  public init(baseUrl: String, plugins: [APIClientPlugin] = [], session: URLSessionProtocol = URLSessionImpl(session: .shared)) {
    self.baseUrl = URL(string: baseUrl)!
    self.plugins = plugins
    self.session = session
    self.requestBuilder = RequestBuilder(baseURL: self.baseUrl)
  }
  
  public func performRequest<T: Decodable>(with requestData: Endpoint, decodingType: T.Type) async throws -> T {
    guard let request = requestBuilder.build(with: requestData) else {
      throw APIClientError.invalidUrlParams
    }
    
    let preparedRequest = plugins.reduce(request) { $1.prepare(request) }
    // Notify plugins
    plugins.forEach { $0.willSend(preparedRequest) }
    
    let (data, response) = try await session.data(for: preparedRequest)
    
    // Notify plugins
    plugins.forEach { $0.didReceive(response, data: data) }
    
    do {
      let result = try JSONDecoder().decode(T.self, from: data)
      return result
    } catch {
      throw APIClientError.decodingError(error)
    }
  }
}
