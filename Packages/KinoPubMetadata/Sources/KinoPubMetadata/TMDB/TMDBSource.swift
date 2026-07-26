import Foundation

/// TMDB implementation of `MetadataSource`. Talks to the Cloudflare Worker proxy;
/// never holds an API key.
public final class TMDBSource: MetadataSource, @unchecked Sendable {
  public let id: MetadataSourceID = .tmdb

  public var isConfigured: Bool { configuration.isConfigured }

  private let configuration: MetadataConfiguration
  private let client: MetadataHTTPClient
  private let cache: MetadataCache

  private static let idTTL: TimeInterval = 60 * 60 * 24 * 365 * 50 // ~forever
  private static let detailsTTL: TimeInterval = 60 * 60 * 24 * 30
  private static let seasonTTL: TimeInterval = 60 * 60 * 12

  public init(
    configuration: MetadataConfiguration,
    client: MetadataHTTPClient = MetadataHTTPClient(),
    cache: MetadataCache = MetadataCache()
  ) {
    self.configuration = configuration
    self.client = client
    self.cache = cache
  }

  // MARK: - MetadataSource

  public func titleMetadata(for identity: MediaIdentity) async throws -> TitleMetadata? {
    guard isConfigured else { throw MetadataError.notConfigured }
    guard let resolved = try await resolveID(for: identity) else {
      return nil
    }
    let details = try await fetchDetails(id: resolved.tmdbId, type: resolved.type)
    return mapDetails(details, type: resolved.type, tmdbId: resolved.tmdbId)
  }

  public func artwork(for identity: MediaIdentity) async throws -> Artwork? {
    try await titleMetadata(for: identity)?.artwork
  }

  public func cast(for identity: MediaIdentity) async throws -> [CastMember] {
    try await titleMetadata(for: identity)?.cast ?? []
  }

  public func nextEpisode(for identity: MediaIdentity) async throws -> EpisodeRef? {
    try await titleMetadata(for: identity)?.nextEpisode
  }

  public func schedule(for identity: MediaIdentity, season: Int) async throws -> [EpisodeSchedule] {
    guard isConfigured else { throw MetadataError.notConfigured }
    guard let resolved = try await resolveID(for: identity), resolved.type == .tv else {
      return []
    }
    return try await fetchSeason(tmdbId: resolved.tmdbId, season: season)
  }

  public func personMetadata(id: Int) async throws -> PersonMetadata? {
    guard isConfigured else { throw MetadataError.notConfigured }
    let details = try await fetchPerson(id: id)
    return mapPerson(details)
  }

  // MARK: - Resolve

  private struct Resolved: Sendable {
    let tmdbId: Int
    let type: TMDBMediaType
  }

  private func resolveID(for identity: MediaIdentity) async throws -> Resolved? {
    guard let imdb = identity.imdb, !imdb.isEmpty else { return nil }
    let key = "tmdb/find/\(imdb)"

    let entry = await cache.deduped(key: key, ttl: Self.idTTL) { [self] in
      do {
        let url = try makeURL(path: "/3/find/\(imdb)", query: [
          URLQueryItem(name: "external_source", value: "imdb_id"),
          URLQueryItem(name: "language", value: configuration.language),
        ])
        let data = try await client.getData(url: url)
        let response = try await client.decode(TMDBFindResponse.self, from: data)
        guard let match = response.match(preferSeries: identity.isSeries) else {
          return MetadataCache.Entry(payload: Data(), isNegative: true)
        }
        let payload = TMDBResolvedID(tmdbId: match.id, type: match.type.rawValue)
        let encoded = try await cache.encode(payload)
        return MetadataCache.Entry(payload: encoded, isNegative: false)
      } catch MetadataError.httpStatus(404) {
        return MetadataCache.Entry(payload: Data(), isNegative: true)
      } catch {
        // Transient — don't cache.
        return nil
      }
    }

    guard let entry, !entry.isNegative else { return nil }
    let resolved = try await cache.decode(TMDBResolvedID.self, from: entry.payload)
    guard let type = TMDBMediaType(rawValue: resolved.type) else { return nil }
    return Resolved(tmdbId: resolved.tmdbId, type: type)
  }

  // MARK: - Details

  private func fetchDetails(id: Int, type: TMDBMediaType) async throws -> TMDBTitleDetails {
    let key = "tmdb/details/\(type.rawValue)/\(id)"
    let entry = await cache.deduped(key: key, ttl: Self.detailsTTL) { [self] in
      do {
        let append: String
        switch type {
        case .movie:
          append = "credits,images,videos,release_dates,keywords,external_ids"
        case .tv:
          append = "aggregate_credits,images,videos,content_ratings,keywords,external_ids"
        }
        let url = try makeURL(path: "/3/\(type.rawValue)/\(id)", query: [
          URLQueryItem(name: "language", value: configuration.language),
          URLQueryItem(name: "append_to_response", value: append),
          URLQueryItem(name: "include_image_language", value: "ru,en,null"),
        ])
        let data = try await client.getData(url: url)
        // Validate before caching.
        _ = try await client.decode(TMDBTitleDetails.self, from: data)
        return MetadataCache.Entry(payload: data)
      } catch {
        return nil
      }
    }
    guard let entry, !entry.isNegative else { throw MetadataError.notFound }
    return try await client.decode(TMDBTitleDetails.self, from: entry.payload)
  }

  private func fetchSeason(tmdbId: Int, season: Int) async throws -> [EpisodeSchedule] {
    let key = "tmdb/season/\(tmdbId)/\(season)"
    let entry = await cache.deduped(key: key, ttl: Self.seasonTTL) { [self] in
      do {
        let url = try makeURL(path: "/3/tv/\(tmdbId)/season/\(season)", query: [
          URLQueryItem(name: "language", value: configuration.language),
        ])
        let data = try await client.getData(url: url)
        _ = try await client.decode(TMDBSeasonDetails.self, from: data)
        return MetadataCache.Entry(payload: data)
      } catch {
        return nil
      }
    }
    guard let entry else { return [] }
    let details = try await client.decode(TMDBSeasonDetails.self, from: entry.payload)
    let seasonNumber = details.seasonNumber ?? season
    return (details.episodes ?? []).compactMap { ep in
      guard let number = ep.episodeNumber else { return nil }
      return EpisodeSchedule(
        episodeNumber: number,
        seasonNumber: seasonNumber,
        name: ep.name,
        overview: ep.overview,
        airDate: Self.parseDate(ep.airDate),
        runtime: ep.runtime,
        still: imageURL(path: ep.stillPath, size: .stillW300)
      )
    }
  }

  private func fetchPerson(id: Int) async throws -> TMDBPersonDetails {
    let key = "tmdb/person/\(id)"
    let entry = await cache.deduped(key: key, ttl: Self.detailsTTL) { [self] in
      do {
        let url = try makeURL(path: "/3/person/\(id)", query: [
          URLQueryItem(name: "language", value: configuration.language),
        ])
        let data = try await client.getData(url: url)
        _ = try await client.decode(TMDBPersonDetails.self, from: data)
        return MetadataCache.Entry(payload: data)
      } catch MetadataError.httpStatus(404) {
        return MetadataCache.Entry(payload: Data(), isNegative: true)
      } catch {
        return nil
      }
    }
    guard let entry, !entry.isNegative else { throw MetadataError.notFound }
    return try await client.decode(TMDBPersonDetails.self, from: entry.payload)
  }

  // MARK: - Mapping

  private func mapPerson(_ details: TMDBPersonDetails) -> PersonMetadata {
    PersonMetadata(
      biography: details.biography.flatMap { $0.isEmpty ? nil : $0 },
      birthday: Self.parseDate(details.birthday),
      placeOfBirth: details.placeOfBirth.flatMap { $0.isEmpty ? nil : $0 },
      photo: imageURL(path: details.profilePath, size: .profileW342),
      knownForDepartment: details.knownForDepartment,
      attribution: [.tmdb]
    )
  }

  private func mapDetails(_ details: TMDBTitleDetails, type: TMDBMediaType, tmdbId: Int) -> TitleMetadata {
    var meta = TitleMetadata()
    meta.attribution.insert(.tmdb)
    meta.tmdbId = tmdbId
    meta.status = details.status
    meta.inProduction = details.inProduction
    meta.keywords = details.keywords?.all.compactMap(\.name) ?? []

    let credits = type == .tv ? (details.aggregateCredits ?? details.credits) : details.credits
    meta.cast = (credits?.cast ?? []).compactMap(mapCast)
    meta.crew = (credits?.crew ?? []).compactMap(mapCrew)

    if let images = details.images {
      meta.artwork = Artwork(
        titleLogo: imageURL(
          path: images.bestLogoPath(preferring: configuration.imageLanguages),
          size: .logoW500
        ),
        poster: imageURL(path: images.bestPosterPath(), size: .posterW780),
        backdrop: imageURL(path: images.bestBackdropPath(), size: .backdropOriginal)
      )
    }

    meta.trailers = (details.videos?.results ?? []).compactMap { video in
      guard let key = video.key, let site = video.site, let type = video.type else { return nil }
      return TrailerRef(
        site: site,
        key: key,
        type: type,
        official: video.official ?? false,
        language: video.iso6391
      )
    }

    meta.ageRating = Self.pickAgeRating(
      releaseDates: details.releaseDates,
      contentRatings: details.contentRatings
    )

    if let next = details.nextEpisodeToAir,
       let season = next.seasonNumber,
       let episode = next.episodeNumber {
      meta.nextEpisode = EpisodeRef(
        seasonNumber: season,
        episodeNumber: episode,
        name: next.name,
        airDate: Self.parseDate(next.airDate)
      )
    }
    if let last = details.lastEpisodeToAir,
       let season = last.seasonNumber,
       let episode = last.episodeNumber {
      meta.lastEpisode = EpisodeRef(
        seasonNumber: season,
        episodeNumber: episode,
        name: last.name,
        airDate: Self.parseDate(last.airDate)
      )
    }

    return meta
  }

  private func mapCast(_ credit: TMDBCredit) -> CastMember? {
    guard let name = credit.name, !name.isEmpty else { return nil }
    let episodeCount = credit.episodeCount
      ?? credit.roles?.compactMap(\.episodeCount).max()
    return CastMember(
      name: name,
      character: credit.primaryCharacter,
      photo: imageURL(path: credit.profilePath, size: .profileW185),
      department: credit.knownDepartmentOrActing,
      tmdbPersonId: credit.id,
      episodeCount: episodeCount,
      order: credit.order
    )
  }

  private func mapCrew(_ credit: TMDBCredit) -> CastMember? {
    guard let name = credit.name, !name.isEmpty else { return nil }
    return CastMember(
      name: name,
      character: credit.job,
      photo: imageURL(path: credit.profilePath, size: .profileW185),
      department: credit.department ?? credit.job,
      tmdbPersonId: credit.id
    )
  }

  private func imageURL(path: String?, size: TMDBImageSize) -> URL? {
    TMDBImageURL.url(path: path, size: size, proxyBase: configuration.proxyBaseURL)
  }

  private static func pickAgeRating(
    releaseDates: TMDBReleaseDates?,
    contentRatings: TMDBContentRatings?
  ) -> String? {
    let preferred = ["RU", "US", "GB"]
    if let ratings = contentRatings?.results {
      for country in preferred {
        if let hit = ratings.first(where: { $0.iso31661 == country }),
           let rating = hit.rating, !rating.isEmpty {
          return rating
        }
      }
      if let any = ratings.first(where: { !($0.rating ?? "").isEmpty })?.rating {
        return any
      }
    }
    if let countries = releaseDates?.results {
      for country in preferred {
        if let dates = countries.first(where: { $0.iso31661 == country })?.releaseDates {
          if let cert = dates.first(where: { !($0.certification ?? "").isEmpty })?.certification {
            return cert
          }
        }
      }
    }
    return nil
  }

  // MARK: - URL

  private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
    guard let base = configuration.proxyBaseURL else { throw MetadataError.notConfigured }
    let baseString = base.absoluteString.hasSuffix("/")
      ? String(base.absoluteString.dropLast())
      : base.absoluteString
    guard var comps = URLComponents(string: baseString + path) else {
      throw MetadataError.badURL
    }
    comps.queryItems = query.isEmpty ? nil : query
    guard let url = comps.url else { throw MetadataError.badURL }
    return url
  }

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  static func parseDate(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    return dateFormatter.date(from: String(raw.prefix(10)))
  }
}

private extension TMDBCredit {
  var knownDepartmentOrActing: String? {
    department ?? "Acting"
  }
}
