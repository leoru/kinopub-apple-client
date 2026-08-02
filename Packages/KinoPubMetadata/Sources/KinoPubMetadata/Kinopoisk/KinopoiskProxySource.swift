import Foundation

/// Keyless Kinopoisk extras via the public `kpapp.link` proxy — the same path the
/// dungeon-master-xx community fork uses. Always configured: no user API key, no
/// Settings UI. Fills facts / stills / cast character names / reviews when the
/// keyed `KinopoiskSource` isn't set up (or as a gap-filler if it fails).
///
/// Endpoints (verified live, no auth):
///   `https://kpapp.link/kpapi/films/<kinopoiskId>/{facts,reviews,staff,images}`
public final class KinopoiskProxySource: MetadataSource, @unchecked Sendable {
  public let id: MetadataSourceID = .kinopoiskProxy

  public var isConfigured: Bool { true }

  private let client: MetadataHTTPClient
  private let cache: MetadataCache
  private let baseURL: String

  private static let ttl: TimeInterval = 60 * 60 * 24 * 30

  public init(
    client: MetadataHTTPClient = MetadataHTTPClient(),
    cache: MetadataCache = MetadataCache(),
    baseURL: String = "https://kpapp.link/kpapi/films"
  ) {
    self.client = client
    self.cache = cache
    self.baseURL = baseURL
  }

  public func titleMetadata(for identity: MediaIdentity) async throws -> TitleMetadata? {
    guard let filmId = identity.kinopoisk, filmId > 0 else { return nil }

    async let factsPart = fetchFacts(filmId: filmId)
    async let imagesPart = fetchImages(filmId: filmId)
    async let staffPart = fetchStaff(filmId: filmId)
    async let reviewsPart = fetchReviews(filmId: filmId)

    var meta = TitleMetadata()
    meta.attribution.insert(.kinopoiskProxy)
    meta.merge(await factsPart)
    meta.merge(await imagesPart)
    meta.merge(await staffPart)
    meta.merge(await reviewsPart)
    return meta
  }

  // MARK: - Endpoints

  private func fetchFacts(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    let (items, debug) = await fetch([ProxyFact].self, filmId: filmId, resource: "facts")
    part.debugLog = [debug]
    part.facts = (items ?? []).compactMap { item in
      let text = KinopoiskSource.stripHTML(item.text)
      guard !text.isEmpty else { return nil }
      return Fact(text: text, isSpoiler: item.spoiler ?? false)
    }
    return part
  }

  private func fetchImages(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    let (items, debug) = await fetch([ProxyImage].self, filmId: filmId, resource: "images")
    part.debugLog = [debug]
    part.stills = (items ?? []).compactMap { item in
      guard let urlString = item.imageUrl, let url = URL(string: urlString) else { return nil }
      return StillImage(url: url, previewURL: item.previewUrl.flatMap(URL.init(string:)))
    }
    return part
  }

  private func fetchStaff(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    let (items, debug) = await fetchStaffMembers(filmId: filmId)
    part.debugLog = [debug]
    let members = items ?? []
    part.cast = members.compactMap { member in
      guard (member.professionKey ?? "").uppercased() == "ACTOR" else { return nil }
      let name = member.displayName
      guard !name.isEmpty else { return nil }
      return CastMember(
        name: name,
        localizedName: member.nameRu,
        character: member.description,
        photo: member.posterUrl.flatMap(\.nonPlaceholderImageURL),
        department: "Acting"
      )
    }
    return part
  }

  private func fetchReviews(filmId: Int) async -> TitleMetadata {
    var part = TitleMetadata()
    let (page, debug) = await fetchReviewsPage(filmId: filmId)
    part.debugLog = [debug]
    part.reviews = (page?.items ?? []).compactMap { item in
      let author = (item.author ?? "").trimmingCharacters(in: .whitespaces)
      let body = KinopoiskSource.stripHTML(item.description ?? "")
      guard !author.isEmpty, !body.isEmpty else { return nil }
      return Review(
        author: author,
        title: (item.title ?? "").trimmingCharacters(in: .whitespaces),
        body: body,
        sentiment: item.type,
        date: item.date
      )
    }
    return part
  }

  // MARK: - Network

  private struct ItemsEnvelope<T: Decodable>: Decodable {
    let items: [T]
  }

  private struct ProxyFact: Decodable {
    let text: String
    let type: String?
    let spoiler: Bool?
  }

  private struct ProxyImage: Decodable {
    let imageUrl: String?
    let previewUrl: String?
  }

  private struct ProxyStaff: Decodable {
    let staffId: Int?
    let nameRu: String?
    let nameEn: String?
    let description: String?
    let posterUrl: String?
    let professionKey: String?

    var displayName: String {
      let ru = (nameRu ?? "").trimmingCharacters(in: .whitespaces)
      if !ru.isEmpty { return ru }
      return (nameEn ?? "").trimmingCharacters(in: .whitespaces)
    }
  }

  private struct ProxyReview: Decodable {
    let kinopoiskId: Int?
    let type: String?
    let date: String?
    let author: String?
    let title: String?
    let description: String?
  }

  private struct ProxyReviewsPage: Decodable {
    let items: [ProxyReview]
  }

  private func fetch<T: Decodable>(
    _ type: [T].Type,
    filmId: Int,
    resource: String
  ) async -> ([T]?, SourceDebugEntry) {
    let urlString = "\(baseURL)/\(filmId)/\(resource)"
    let key = "kinopoiskProxy/\(resource)/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.ttl) { [self] in
      await getAndCache(urlString: urlString, type: ItemsEnvelope<T>.self)
    }
    let debug = SourceDebugEntry(
      source: .kinopoiskProxy,
      endpoint: resource,
      url: urlString,
      proxied: true,
      succeeded: entry != nil && !(entry?.isNegative ?? true),
      responseBody: entry.map { String(data: $0.payload.prefix(8_192), encoding: .utf8) ?? "" } ?? ""
    )
    guard let entry, !entry.isNegative else { return (nil, debug) }
    let decoded = try? client.decode(ItemsEnvelope<T>.self, from: entry.payload)
    return (decoded?.items, debug)
  }

  private func fetchStaffMembers(filmId: Int) async -> ([ProxyStaff]?, SourceDebugEntry) {
    let urlString = "\(baseURL)/\(filmId)/staff"
    let key = "kinopoiskProxy/staff/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.ttl) { [self] in
      await getAndCache(urlString: urlString, type: [ProxyStaff].self)
    }
    let debug = SourceDebugEntry(
      source: .kinopoiskProxy,
      endpoint: "staff",
      url: urlString,
      proxied: true,
      succeeded: entry != nil && !(entry?.isNegative ?? true),
      responseBody: entry.map { String(data: $0.payload.prefix(8_192), encoding: .utf8) ?? "" } ?? ""
    )
    guard let entry, !entry.isNegative else { return (nil, debug) }
    return (try? client.decode([ProxyStaff].self, from: entry.payload), debug)
  }

  private func fetchReviewsPage(filmId: Int) async -> (ProxyReviewsPage?, SourceDebugEntry) {
    let urlString = "\(baseURL)/\(filmId)/reviews"
    let key = "kinopoiskProxy/reviews/\(filmId)"
    let entry = await cache.deduped(key: key, ttl: Self.ttl) { [self] in
      await getAndCache(urlString: urlString, type: ProxyReviewsPage.self)
    }
    let debug = SourceDebugEntry(
      source: .kinopoiskProxy,
      endpoint: "reviews",
      url: urlString,
      proxied: true,
      succeeded: entry != nil && !(entry?.isNegative ?? true),
      responseBody: entry.map { String(data: $0.payload.prefix(8_192), encoding: .utf8) ?? "" } ?? ""
    )
    guard let entry, !entry.isNegative else { return (nil, debug) }
    return (try? client.decode(ProxyReviewsPage.self, from: entry.payload), debug)
  }

  private func getAndCache<T: Decodable>(
    urlString: String,
    type: T.Type
  ) async -> MetadataCache.Entry? {
    guard let url = URL(string: urlString) else { return nil }
    do {
      let data = try await client.getData(url: url, headers: [:])
      _ = try client.decode(T.self, from: data)
      return MetadataCache.Entry(payload: data)
    } catch MetadataError.httpStatus(404) {
      return MetadataCache.Entry(payload: Data(), isNegative: true)
    } catch {
      return nil
    }
  }
}
