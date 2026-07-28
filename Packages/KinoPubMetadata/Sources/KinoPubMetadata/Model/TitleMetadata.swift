import Foundation

public struct Artwork: Sendable, Hashable {
  public var titleLogo: URL?
  public var poster: URL?
  public var backdrop: URL?

  public init(titleLogo: URL? = nil, poster: URL? = nil, backdrop: URL? = nil) {
    self.titleLogo = titleLogo
    self.poster = poster
    self.backdrop = backdrop
  }
}

/// A studio (movies) or distribution network/service (TV — HBO, Netflix...).
public struct ProductionCompany: Sendable, Hashable, Identifiable {
  public var id: String { name }
  public let name: String
  public let logoURL: URL?
  public let originCountry: String?

  public init(name: String, logoURL: URL? = nil, originCountry: String? = nil) {
    self.name = name
    self.logoURL = logoURL
    self.originCountry = originCountry
  }
}

public struct CastMember: Sendable, Hashable, Identifiable {
  public var id: String { "\(tmdbPersonId.map(String.init) ?? name):\(department ?? "")" }

  public let name: String
  public var localizedName: String?
  public var character: String?
  public var photo: URL?
  public var department: String?
  public var tmdbPersonId: Int?
  public var episodeCount: Int?
  public var order: Int?

  public init(
    name: String,
    localizedName: String? = nil,
    character: String? = nil,
    photo: URL? = nil,
    department: String? = nil,
    tmdbPersonId: Int? = nil,
    episodeCount: Int? = nil,
    order: Int? = nil
  ) {
    self.name = name
    self.localizedName = localizedName
    self.character = character
    self.photo = photo
    self.department = department
    self.tmdbPersonId = tmdbPersonId
    self.episodeCount = episodeCount
    self.order = order
  }
}

public struct EpisodeSchedule: Sendable, Hashable, Identifiable {
  public var id: Int { episodeNumber }

  public let episodeNumber: Int
  public let seasonNumber: Int
  public var name: String?
  public var overview: String?
  public var airDate: Date?
  public var runtime: Int?
  public var still: URL?

  public init(
    episodeNumber: Int,
    seasonNumber: Int,
    name: String? = nil,
    overview: String? = nil,
    airDate: Date? = nil,
    runtime: Int? = nil,
    still: URL? = nil
  ) {
    self.episodeNumber = episodeNumber
    self.seasonNumber = seasonNumber
    self.name = name
    self.overview = overview
    self.airDate = airDate
    self.runtime = runtime
    self.still = still
  }

  /// True when the episode has a known air date in the future (local calendar day).
  public var isUpcoming: Bool {
    guard let airDate else { return false }
    return Calendar.current.startOfDay(for: airDate) > Calendar.current.startOfDay(for: Date())
  }
}

public struct EpisodeRef: Sendable, Hashable {
  public let seasonNumber: Int
  public let episodeNumber: Int
  public var name: String?
  public var airDate: Date?

  public init(seasonNumber: Int, episodeNumber: Int, name: String? = nil, airDate: Date? = nil) {
    self.seasonNumber = seasonNumber
    self.episodeNumber = episodeNumber
    self.name = name
    self.airDate = airDate
  }
}

public struct Award: Sendable, Hashable {
  public let name: String
  public let nominationName: String?
  public let year: Int?
  public let won: Bool

  public init(name: String, nominationName: String? = nil, year: Int? = nil, won: Bool = false) {
    self.name = name
    self.nominationName = nominationName
    self.year = year
    self.won = won
  }
}

public struct SkipSegments: Sendable, Hashable {
  public struct Segment: Sendable, Hashable {
    public let startMs: Int
    public let endMs: Int
    public init(startMs: Int, endMs: Int) {
      self.startMs = startMs
      self.endMs = endMs
    }
  }

  public var intro: Segment?
  public var recap: Segment?
  public var outro: Segment?

  public init(intro: Segment? = nil, recap: Segment? = nil, outro: Segment? = nil) {
    self.intro = intro
    self.recap = recap
    self.outro = outro
  }
}

/// A gallery image (stills, not the single hero poster/backdrop in `Artwork`).
public struct StillImage: Sendable, Hashable, Identifiable {
  public var id: String { url.absoluteString }
  public let url: URL
  public let previewURL: URL?

  public init(url: URL, previewURL: URL? = nil) {
    self.url = url
    self.previewURL = previewURL
  }
}

public struct Fact: Sendable, Hashable, Identifiable {
  public var id: String { text }
  public let text: String
  public let isSpoiler: Bool

  public init(text: String, isSpoiler: Bool = false) {
    self.text = text
    self.isSpoiler = isSpoiler
  }
}

public struct TrailerRef: Sendable, Hashable {
  public let site: String
  public let key: String
  public let type: String
  public let official: Bool
  public let language: String?

  public init(site: String, key: String, type: String, official: Bool, language: String?) {
    self.site = site
    self.key = key
    self.type = type
    self.official = official
    self.language = language
  }
}

/// Dev-facing record of one raw HTTP call a source made while building this
/// `TitleMetadata` — what URL, whether it went through our proxy, whether it
/// succeeded, and the raw response body. Powers the debug button on the item
/// page footer; not for end-user display.
public struct SourceDebugEntry: Sendable, Hashable, Identifiable {
  public var id: String { source.rawValue + endpoint + url }
  public let source: MetadataSourceID
  public let endpoint: String
  public let url: String
  public let proxied: Bool
  public let succeeded: Bool
  public let responseBody: String

  public init(
    source: MetadataSourceID,
    endpoint: String,
    url: String,
    proxied: Bool,
    succeeded: Bool,
    responseBody: String
  ) {
    self.source = source
    self.endpoint = endpoint
    self.url = url
    self.proxied = proxied
    self.succeeded = succeeded
    self.responseBody = responseBody
  }
}

/// Merged overlay the UI reads. kino.pub remains the base; this only fills gaps.
public struct TitleMetadata: Sendable {
  public var cast: [CastMember] = []
  public var crew: [CastMember] = []
  public var artwork: Artwork = Artwork()
  public var schedule: [Int: [EpisodeSchedule]] = [:]
  public var awards: [Award] = []
  public var stills: [StillImage] = []
  public var facts: [Fact] = []
  public var nextEpisode: EpisodeRef?
  public var lastEpisode: EpisodeRef?
  public var status: String?
  public var inProduction: Bool?
  public var ageRating: String?
  public var keywords: [String] = []
  public var trailers: [TrailerRef] = []
  public var tagline: String?
  public var homepage: URL?
  /// Movie-only; both nil for series (TMDB doesn't report box office for TV).
  public var budget: Int?
  public var revenue: Int?
  public var productionCompanies: [ProductionCompany] = []
  public var tmdbId: Int?
  public var attribution: Set<MetadataSourceID> = []
  /// Every raw HTTP call any source made for this title, across the whole merge —
  /// concatenated, not "fill gap" like the other fields. Dev/debug only.
  public var debugLog: [SourceDebugEntry] = []

  public init() {}

  public var titleLogoURL: URL? { artwork.titleLogo }

  public mutating func merge(_ other: TitleMetadata) {
    if cast.isEmpty { cast = other.cast }
    else { cast = Self.mergeCast(base: cast, overlay: other.cast) }
    if crew.isEmpty { crew = other.crew }
    if artwork.titleLogo == nil { artwork.titleLogo = other.artwork.titleLogo }
    if artwork.poster == nil { artwork.poster = other.artwork.poster }
    if artwork.backdrop == nil { artwork.backdrop = other.artwork.backdrop }
    for (season, episodes) in other.schedule {
      if schedule[season] == nil { schedule[season] = episodes }
    }
    if awards.isEmpty { awards = other.awards }
    if stills.isEmpty { stills = other.stills }
    if facts.isEmpty { facts = other.facts }
    if nextEpisode == nil { nextEpisode = other.nextEpisode }
    if lastEpisode == nil { lastEpisode = other.lastEpisode }
    if status == nil { status = other.status }
    if inProduction == nil { inProduction = other.inProduction }
    if ageRating == nil { ageRating = other.ageRating }
    if keywords.isEmpty { keywords = other.keywords }
    if trailers.isEmpty { trailers = other.trailers }
    if tagline == nil { tagline = other.tagline }
    if homepage == nil { homepage = other.homepage }
    if budget == nil { budget = other.budget }
    if revenue == nil { revenue = other.revenue }
    if productionCompanies.isEmpty { productionCompanies = other.productionCompanies }
    if tmdbId == nil { tmdbId = other.tmdbId }
    attribution.formUnion(other.attribution)
    debugLog.append(contentsOf: other.debugLog)
  }

  /// Prefer existing name order; fill photo/character from overlay by normalized name.
  public static func mergeCast(base: [CastMember], overlay: [CastMember]) -> [CastMember] {
    let byName = Dictionary(overlay.map { (Self.normalize($0.name), $0) },
                            uniquingKeysWith: { first, _ in first })
    return base.map { member in
      guard let hit = byName[Self.normalize(member.name)] else { return member }
      var merged = member
      if merged.character == nil || merged.character?.isEmpty == true {
        merged.character = hit.character
      }
      if merged.photo == nil { merged.photo = hit.photo }
      if merged.tmdbPersonId == nil { merged.tmdbPersonId = hit.tmdbPersonId }
      if merged.episodeCount == nil { merged.episodeCount = hit.episodeCount }
      return merged
    }
  }

  /// Enrich kino.pub name list with TMDB cast/crew data, keeping kino.pub order.
  public static func enrich(
    names: [String],
    roleDepartment: String?,
    from metadata: TitleMetadata
  ) -> [CastMember] {
    let pool = metadata.cast + metadata.crew
    let byName = Dictionary(pool.map { (Self.normalize($0.name), $0) },
                            uniquingKeysWith: { first, _ in first })
    return names.map { name in
      if let hit = byName[Self.normalize(name)] {
        var member = hit
        member = CastMember(
          name: name,
          localizedName: hit.localizedName,
          character: hit.character,
          photo: hit.photo,
          department: roleDepartment ?? hit.department,
          tmdbPersonId: hit.tmdbPersonId,
          episodeCount: hit.episodeCount,
          order: hit.order
        )
        return member
      }
      return CastMember(name: name, department: roleDepartment)
    }
  }

  public static func normalize(_ name: String) -> String {
    name.folding(options: .diacriticInsensitive, locale: .current)
      .lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
