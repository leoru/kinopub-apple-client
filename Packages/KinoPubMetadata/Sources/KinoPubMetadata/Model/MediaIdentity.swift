import Foundation

/// Everything needed to identify a title in external catalogs.
/// Built once from kino.pub's `MediaItem` — never used for title-matching.
public struct MediaIdentity: Hashable, Sendable {
  public let kinopubId: Int
  /// IMDb id as `tt0903747`. Nil when kino.pub has no imdb field.
  public let imdb: String?
  public let kinopoisk: Int?
  public let title: String
  public let originalTitle: String
  public let year: Int
  public let isSeries: Bool

  public init(
    kinopubId: Int,
    imdb: String?,
    kinopoisk: Int?,
    title: String,
    originalTitle: String,
    year: Int,
    isSeries: Bool
  ) {
    self.kinopubId = kinopubId
    self.imdb = imdb
    self.kinopoisk = kinopoisk
    self.title = title
    self.originalTitle = originalTitle
    self.year = year
    self.isSeries = isSeries
  }
}
