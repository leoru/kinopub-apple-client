import Foundation

/// Supplies the per-user Kinopoisk Unofficial API key at call time (Settings can
/// change it while the app is running — this is read fresh on every request, the
/// same "no caching, ask each time" approach `AccessTokenServiceImpl` uses for the
/// kino.pub token). Returning `nil` means "not configured" — including when a key
/// is stored but hasn't passed validation; gating that is the provider's job, not
/// this source's, so this package stays UI/storage-agnostic.
public protocol KinopoiskKeyProviding: Sendable {
  func currentAPIKey() -> String?
}

/// Kinopoisk Unofficial (kinopoiskapiunofficial.tech) implementation of
/// `MetadataSource` — a third-party service, not an official Kinopoisk product.
/// Contributes what TMDB doesn't: a stills gallery, "facts" about the title,
/// awards, and Russian character names on the cast list. Client-only: talks to
/// the service directly with the user's own key, no backend of ours involved.
public final class KinopoiskSource: MetadataSource, @unchecked Sendable {
  public let id: MetadataSourceID = .kinopoisk

  public var isConfigured: Bool {
    !(keyProvider.currentAPIKey()?.isEmpty ?? true)
  }

  private let keyProvider: KinopoiskKeyProviding
  private let client: MetadataHTTPClient
  private let cache: MetadataCache

  private static let baseURL = "https://kinopoiskapiunofficial.tech"
  // Longer than TMDB's 30-day TTL — stills/facts/awards/cast don't change often.
  private static let detailsTTL: TimeInterval = 60 * 60 * 24 * 90

  public init(
    keyProvider: KinopoiskKeyProviding,
    client: MetadataHTTPClient = MetadataHTTPClient(),
    cache: MetadataCache = MetadataCache()
  ) {
    self.keyProvider = keyProvider
    self.client = client
    self.cache = cache
  }

  // MARK: - MetadataSource

  public func titleMetadata(for identity: MediaIdentity) async throws -> TitleMetadata? {
    guard isConfigured else { throw MetadataError.notConfigured }
    guard let filmId = identity.kinopoisk, filmId > 0 else { return nil }

    async let detailsPart = fetchDetailsPart(filmId: filmId)
    async let staffPart = fetchStaffPart(filmId: filmId)
    async let awardsPart = fetchAwardsPart(filmId: filmId)
    async let stillsPart = fetchStillsPart(filmId: filmId)
    async let factsPart = fetchFactsPart(filmId: filmId)

    var meta = TitleMetadata()
    meta.attribution.insert(.kinopoisk)
    meta.merge(await detailsPart)
    meta.merge(await staffPart)
    meta.merge(await awardsPart)
    meta.merge(await stillsPart)
    meta.merge(await factsPart)
    return meta
  }

  public func artwork(for identity: MediaIdentity) async throws -> Artwork? {
    try await titleMetadata(for: identity)?.artwork
  }

  public func awards(for identity: MediaIdentity) async throws -> [Award] {
    try await titleMetadata(for: identity)?.awards ?? []
  }

  public func cast(for identity: MediaIdentity) async throws -> [CastMember] {
    try await titleMetadata(for: identity)?.cast ?? []
  }

  // schedule, nextEpisode, segments, personMetadata(id:) — not covered by this
  // source; protocol defaults (empty/nil) apply. Person-bio enrichment needs a
  // Kinopoisk staffId slot that doesn't exist on CastMember/MediaPerson yet —
  // deliberately deferred, see the plan for this feature.

  // MARK: - Fetches (each independently failable — one endpoint erroring doesn't
  // blank the others; `titleMetadata` just gets a partial result)

  /// Artwork only — a fallback for whatever TMDB didn't have, since `merge` only
  /// fills gaps. Everything else on the details payload (ratings, description,
  /// tagline...) already comes from kino.pub's own `MediaItem`, so it's not
  /// re-modeled here.
  private func fetchDetailsPart(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    guard let details = try? await fetchDetails(filmId: filmId) else { return part }
    part.artwork = Artwork(
      titleLogo: details.logoUrl.flatMap(URL.init(string:)),
      poster: details.posterUrl.flatMap(URL.init(string:)),
      backdrop: details.coverUrl.flatMap(URL.init(string:))
    )
    return part
  }

  private func fetchStaffPart(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    guard let members = try? await fetchStaff(filmId: filmId) else { return part }
    var cast: [CastMember] = []
    var crew: [CastMember] = []
    for member in members {
      guard let name = member.nameRu, !name.isEmpty else { continue }
      let isActor = member.professionKey == "ACTOR"
      let character = isActor ? Self.splitCharacter(description: member.description, name: name) : nil
      let credit = CastMember(
        name: name,
        character: character,
        photo: member.posterUrl.flatMap(URL.init(string:)),
        department: member.professionText
      )
      if isActor { cast.append(credit) } else { crew.append(credit) }
    }
    part.cast = cast
    part.crew = crew
    return part
  }

  private func fetchAwardsPart(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    guard let response = try? await fetchAwards(filmId: filmId) else { return part }
    part.awards = response.items.compactMap { item in
      guard let name = item.name else { return nil }
      return Award(name: name, nominationName: item.nominationName, year: item.year, won: item.win ?? false)
    }
    return part
  }

  private func fetchStillsPart(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    guard let response = try? await fetchImages(filmId: filmId) else { return part }
    part.stills = response.items.compactMap { item in
      guard let urlString = item.imageUrl, let url = URL(string: urlString) else { return nil }
      return StillImage(url: url, previewURL: item.previewUrl.flatMap(URL.init(string:)))
    }
    return part
  }

  private func fetchFactsPart(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    guard let response = try? await fetchFacts(filmId: filmId) else { return part }
    part.facts = response.items.compactMap { item in
      guard let raw = item.text, !raw.isEmpty else { return nil }
      return Fact(text: Self.stripHTML(raw), isSpoiler: item.spoiler ?? false)
    }
    return part
  }

  // MARK: - Network + cache

  private func fetchDetails(filmId: Int) async throws -> KinopoiskFilmDetails {
    let key = "kinopoisk/details/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.detailsTTL) { [self] in
      await fetchAndCache(path: "/api/v2.2/films/\(filmId)", query: [], type: KinopoiskFilmDetails.self)
    }
    guard let entry, !entry.isNegative else { throw MetadataError.notFound }
    return try await client.decode(KinopoiskFilmDetails.self, from: entry.payload)
  }

  private func fetchStaff(filmId: Int) async throws -> [KinopoiskStaffMember] {
    let key = "kinopoisk/staff/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.detailsTTL) { [self] in
      await fetchAndCache(path: "/api/v1/staff", query: [URLQueryItem(name: "filmId", value: "\(filmId)")],
                           type: [KinopoiskStaffMember].self)
    }
    guard let entry, !entry.isNegative else { return [] }
    return try await client.decode([KinopoiskStaffMember].self, from: entry.payload)
  }

  private func fetchAwards(filmId: Int) async throws -> KinopoiskAwardsResponse {
    let key = "kinopoisk/awards/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.detailsTTL) { [self] in
      await fetchAndCache(path: "/api/v2.2/films/\(filmId)/awards", query: [],
                           type: KinopoiskAwardsResponse.self)
    }
    guard let entry, !entry.isNegative else { return KinopoiskAwardsResponse(total: 0, items: []) }
    return try await client.decode(KinopoiskAwardsResponse.self, from: entry.payload)
  }

  private func fetchImages(filmId: Int) async throws -> KinopoiskImagesResponse {
    let key = "kinopoisk/images/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.detailsTTL) { [self] in
      await fetchAndCache(
        path: "/api/v2.2/films/\(filmId)/images",
        query: [URLQueryItem(name: "type", value: "STILL"), URLQueryItem(name: "page", value: "1")],
        type: KinopoiskImagesResponse.self
      )
    }
    guard let entry, !entry.isNegative else { return KinopoiskImagesResponse(total: 0, totalPages: 0, items: []) }
    return try await client.decode(KinopoiskImagesResponse.self, from: entry.payload)
  }

  private func fetchFacts(filmId: Int) async throws -> KinopoiskFactsResponse {
    let key = "kinopoisk/facts/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.detailsTTL) { [self] in
      await fetchAndCache(path: "/api/v2.2/films/\(filmId)/facts", query: [],
                           type: KinopoiskFactsResponse.self)
    }
    guard let entry, !entry.isNegative else { return KinopoiskFactsResponse(total: 0, items: []) }
    return try await client.decode(KinopoiskFactsResponse.self, from: entry.payload)
  }

  /// Shared fetch-decode-validate-cache step every endpoint above uses.
  private func fetchAndCache<T: Decodable>(
    path: String, query: [URLQueryItem], type: T.Type
  ) async -> MetadataCache.Entry? {
    guard let key = keyProvider.currentAPIKey(), !key.isEmpty else { return nil }
    do {
      let url = try makeURL(path: path, query: query)
      let data = try await client.getData(url: url, headers: ["X-API-KEY": key])
      _ = try await client.decode(T.self, from: data) // validate before caching
      return MetadataCache.Entry(payload: data)
    } catch MetadataError.httpStatus(404) {
      return MetadataCache.Entry(payload: Data(), isNegative: true)
    } catch {
      return nil // transient (network blip, 402 quota, invalid key) — don't cache
    }
  }

  private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
    guard var comps = URLComponents(string: Self.baseURL + path) else { throw MetadataError.badURL }
    comps.queryItems = query.isEmpty ? nil : query
    guard let url = comps.url else { throw MetadataError.badURL }
    return url
  }

  // MARK: - Mapping helpers

  /// Actor rows carry `"Actor Name — Character Name"` in `description`; everything
  /// else (director, no character) is left as-is.
  static func splitCharacter(description: String?, name: String) -> String? {
    guard let description, !description.isEmpty else { return nil }
    let separators = [" — ", "—"]
    guard let sep = separators.first(where: { description.contains($0) }) else { return description }
    let parts = description.components(separatedBy: sep)
    guard parts.count >= 2 else { return description }
    let prefix = parts[0].trimmingCharacters(in: .whitespaces)
    let rest = parts.dropFirst().joined(separator: sep).trimmingCharacters(in: .whitespaces)
    if prefix == name.trimmingCharacters(in: .whitespaces) {
      return rest.isEmpty ? nil : rest
    }
    return description
  }

  /// Facts arrive with embedded `<a href=...>` markup and numeric HTML entities.
  static func stripHTML(_ raw: String) -> String {
    var text = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    let entities: [String: String] = [
      "&#160;": " ", "&nbsp;": " ", "&amp;": "&", "&quot;": "\"",
      "&#39;": "'", "&laquo;": "«", "&raquo;": "»",
    ]
    for (entity, replacement) in entities {
      text = text.replacingOccurrences(of: entity, with: replacement)
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
