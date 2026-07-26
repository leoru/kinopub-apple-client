import Foundation

/// Minimal HTTP client that surfaces status codes (unlike KinoPubBackend.APIClient).
public actor MetadataHTTPClient {
  private let session: URLSession
  private let decoder: JSONDecoder

  public init(session: URLSession = .shared) {
    self.session = session
    // Explicit CodingKeys on DTOs — do not use convertFromSnakeCase.
    self.decoder = JSONDecoder()
  }

  public func getData(url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw MetadataError.httpStatus(-1)
    }
    guard (200..<300).contains(http.statusCode) else {
      throw MetadataError.httpStatus(http.statusCode)
    }
    return data
  }

  public func get<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
    let data = try await getData(url: url)
    return try decode(T.self, from: data)
  }

  /// Decode from raw data — used by tests with fixtures and by the disk cache.
  public nonisolated func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw MetadataError.decodingFailed
    }
  }
}
