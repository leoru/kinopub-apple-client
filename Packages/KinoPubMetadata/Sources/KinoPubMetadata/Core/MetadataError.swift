import Foundation

public enum MetadataSourceID: String, Sendable, Hashable, Codable {
  case tmdb
  case trakt
  case kinopoisk
  case introdb
}

public enum MetadataError: Error, Sendable, Equatable {
  case notConfigured
  case badURL
  case httpStatus(Int)
  case decodingFailed
  case notFound
}
