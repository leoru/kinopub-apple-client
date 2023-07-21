//
//  APIClient.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class APIClient {
  private let session: URLSession
  private let requestBuilder: RequestBuilder
  private let baseUrl: URL
  private var plugins: [APIClientPlugin]
  
  init(baseUrl: String, plugins: [APIClientPlugin] = [], session: URLSession = .shared) {
    self.baseUrl = URL(string: baseUrl)!
    self.plugins = plugins
    self.session = session
    self.requestBuilder = RequestBuilder(baseURL: self.baseUrl)
  }
  
  func performRequest<T: Decodable>(with requestData: Endpoint) async throws -> T {
    guard let request = requestBuilder.build(with: requestData) else {
      throw APIClientError.invalidUrlParams
    }
    
    // Notify plugins
    plugins.forEach { $0.willSend(request) }
    
    let (data, response) = try await session.data(for: request)
    
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
