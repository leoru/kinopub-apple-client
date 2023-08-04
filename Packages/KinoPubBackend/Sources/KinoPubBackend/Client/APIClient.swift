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

    return try decode(T.self, from: data, throwDecodingErrorImmediately: false)
  }

  private func decode<T: Decodable>(_ type: T.Type,
                                    from data: Data,
                                    throwDecodingErrorImmediately: Bool) throws -> T where T: Decodable {
    do {
      let result = try JSONDecoder().decode(T.self, from: data)
      return result
    } catch {
      if throwDecodingErrorImmediately {
        throw APIClientError.decodingError(error)
      }
      let result = try decode(BackendError.self, from: data, throwDecodingErrorImmediately: true)
      throw APIClientError.networkError(result)
    }
  }
}
