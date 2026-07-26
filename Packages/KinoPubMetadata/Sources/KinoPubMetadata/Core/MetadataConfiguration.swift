import Foundation

public struct MetadataConfiguration: Sendable {
  /// Cloudflare Worker base URL, e.g. `https://kinopub-tmdb-proxy.example.workers.dev`.
  /// No trailing slash. Empty / nil → TMDB source is not configured.
  public let proxyBaseURL: URL?
  public let language: String
  /// Preferred logo languages, in order. `nil` means language-agnostic artwork.
  public let imageLanguages: [String?]

  public init(
    proxyBaseURL: URL?,
    language: String = "ru-RU",
    imageLanguages: [String?] = ["ru", "en", nil]
  ) {
    self.proxyBaseURL = proxyBaseURL
    self.language = language
    self.imageLanguages = imageLanguages
  }

  public var isConfigured: Bool { proxyBaseURL != nil }
}
