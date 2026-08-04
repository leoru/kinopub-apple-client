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
  private let cache: ResponseCaching?

  public init(baseUrl: String,
              plugins: [APIClientPlugin] = [],
              session: URLSessionProtocol = URLSessionImpl(session: .shared),
              cache: ResponseCaching? = nil) {
    self.baseUrl = URL(string: baseUrl)!
    self.plugins = plugins
    self.session = session
    self.cache = cache
    self.requestBuilder = RequestBuilder(baseURL: self.baseUrl)
  }

  /// - Parameter forceRefresh: when true, skips any cached value and always hits the network
  ///   (the fresh result still updates the cache).
  public func performRequest<T: Decodable>(with requestData: Endpoint,
                                           decodingType: T.Type,
                                           forceRefresh: Bool = false) async throws -> T {
    let cacheable = requestData as? CacheableRequest
    let policy = cacheable?.cachePolicy ?? .noCache
    if !forceRefresh, let cacheable, policy.ttl != nil,
       let cachedData = cache?.data(for: cacheable.cacheKey),
       let cached = try? JSONDecoder().decode(T.self, from: cachedData) {
      return cached
    }

    guard let request = requestBuilder.build(with: requestData) else {
      throw APIClientError.invalidUrlParams
    }

    let preparedRequest = plugins.reduce(request) { $1.prepare($0) }
    plugins.forEach { $0.willSend(preparedRequest) }

    let (data, response) = try await session.data(for: preparedRequest)

    plugins.forEach { $0.didReceive(response, data: data) }

    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      // Keep structured kino.pub / OAuth envelopes as BackendError so auth
      // call sites (invalid_grant → logout) keep working.
      if let backendError = try? JSONDecoder().decode(BackendError.self, from: data) {
        throw APIClientError.networkError(backendError)
      }
      throw APIClientError.httpStatus(http.statusCode, data: data)
    }

    let result = try decode(T.self, from: data, throwDecodingErrorImmediately: false)
    if let cacheable, let ttl = policy.ttl {
      cache?.store(data, for: cacheable.cacheKey, ttl: ttl, persist: policy.persistsToDisk)
    }
    return result
  }

  /// Drops all cached responses. Not used on logout — we only cache immutable
  /// genres/countries lists that are shared across accounts.
  public func clearCache() {
    cache?.clear()
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

      if let backendError = try? JSONDecoder().decode(BackendError.self, from: data) {
        throw APIClientError.networkError(backendError)
      }

      throw APIClientError.decodingError(error)
    }
  }
}
