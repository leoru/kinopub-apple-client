import Foundation

enum TMDBMediaType: String, Codable, Sendable {
  case movie
  case tv
}

// MARK: - Find

struct TMDBFindResponse: Codable, Sendable {
  let movieResults: [TMDBFindResult]
  let tvResults: [TMDBFindResult]

  enum CodingKeys: String, CodingKey {
    case movieResults = "movie_results"
    case tvResults = "tv_results"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    movieResults = (try? c.decode([TMDBFindResult].self, forKey: .movieResults)) ?? []
    tvResults = (try? c.decode([TMDBFindResult].self, forKey: .tvResults)) ?? []
  }

  func match(preferSeries: Bool) -> (id: Int, type: TMDBMediaType)? {
    if preferSeries, let tv = tvResults.first {
      return (tv.id, .tv)
    }
    if let movie = movieResults.first {
      return (movie.id, .movie)
    }
    if let tv = tvResults.first {
      return (tv.id, .tv)
    }
    return nil
  }
}

struct TMDBFindResult: Codable, Sendable {
  let id: Int
}

// MARK: - Details (movie / tv with append_to_response)

struct TMDBTitleDetails: Codable, Sendable {
  let id: Int
  let overview: String?
  let tagline: String?
  let homepage: String?
  let status: String?
  let inProduction: Bool?
  let genres: [TMDBNamed]?
  /// Movie-only.
  let budget: Int?
  let revenue: Int?
  let productionCompanies: [TMDBCompany]?
  /// TV-only — the distribution service (HBO, Netflix...), distinct from who
  /// produced it.
  let networks: [TMDBCompany]?
  let credits: TMDBCredits?
  let aggregateCredits: TMDBCredits?
  let images: TMDBImages?
  let videos: TMDBVideos?
  let keywords: TMDBKeywords?
  let externalIds: TMDBExternalIDs?
  let releaseDates: TMDBReleaseDates?
  let contentRatings: TMDBContentRatings?
  let nextEpisodeToAir: TMDBEpisodeAir?
  let lastEpisodeToAir: TMDBEpisodeAir?

  enum CodingKeys: String, CodingKey {
    case id, overview, tagline, homepage, status, genres, budget, revenue, networks
    case credits, images, videos, keywords
    case inProduction = "in_production"
    case productionCompanies = "production_companies"
    case aggregateCredits = "aggregate_credits"
    case externalIds = "external_ids"
    case releaseDates = "release_dates"
    case contentRatings = "content_ratings"
    case nextEpisodeToAir = "next_episode_to_air"
    case lastEpisodeToAir = "last_episode_to_air"
  }
}

struct TMDBCompany: Codable, Sendable {
  let name: String?
  let logoPath: String?
  let originCountry: String?

  enum CodingKeys: String, CodingKey {
    case name
    case logoPath = "logo_path"
    case originCountry = "origin_country"
  }
}

struct TMDBNamed: Codable, Sendable {
  let id: Int?
  let name: String?
}

struct TMDBCredits: Codable, Sendable {
  let cast: [TMDBCredit]?
  let crew: [TMDBCredit]?
}

struct TMDBCredit: Codable, Sendable {
  let id: Int?
  let name: String?
  let character: String?
  let job: String?
  let department: String?
  let profilePath: String?
  let order: Int?
  let episodeCount: Int?
  let roles: [TMDBRole]?

  enum CodingKeys: String, CodingKey {
    case id, name, character, job, department, order, roles
    case profilePath = "profile_path"
    case episodeCount = "episode_count"
  }

  /// Movie uses `character`; TV aggregate uses `roles[].character`.
  var primaryCharacter: String? {
    if let character, !character.isEmpty { return character }
    return roles?.first(where: { !($0.character ?? "").isEmpty })?.character
  }
}

struct TMDBRole: Codable, Sendable {
  let character: String?
  let episodeCount: Int?

  enum CodingKeys: String, CodingKey {
    case character
    case episodeCount = "episode_count"
  }
}

struct TMDBImages: Codable, Sendable {
  let logos: [TMDBImageEntry]
  let posters: [TMDBImageEntry]
  let backdrops: [TMDBImageEntry]

  enum CodingKeys: String, CodingKey {
    case logos, posters, backdrops
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    logos = (try? c.decode([TMDBImageEntry].self, forKey: .logos)) ?? []
    posters = (try? c.decode([TMDBImageEntry].self, forKey: .posters)) ?? []
    backdrops = (try? c.decode([TMDBImageEntry].self, forKey: .backdrops)) ?? []
  }

  init(logos: [TMDBImageEntry] = [], posters: [TMDBImageEntry] = [], backdrops: [TMDBImageEntry] = []) {
    self.logos = logos
    self.posters = posters
    self.backdrops = backdrops
  }

  /// ru → en → nil → any; within a tier, highest vote_average.
  func bestLogoPath(preferring languages: [String?] = ["ru", "en", nil]) -> String? {
    let candidates = logos.filter { !($0.filePath ?? "").isEmpty }
    guard !candidates.isEmpty else { return nil }

    func bestByVote(_ entries: [TMDBImageEntry]) -> TMDBImageEntry? {
      entries.max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) })
    }

    for language in languages {
      let tier = candidates.filter { $0.iso6391 == language }
      if let pick = bestByVote(tier) { return pick.filePath }
    }
    return bestByVote(candidates)?.filePath
  }

  func bestPosterPath() -> String? {
    posters
      .filter { !($0.filePath ?? "").isEmpty }
      .max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) })?
      .filePath
  }

  func bestBackdropPath() -> String? {
    backdrops
      .filter { !($0.filePath ?? "").isEmpty }
      .max(by: { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) })?
      .filePath
  }
}

struct TMDBImageEntry: Codable, Sendable {
  let filePath: String?
  let iso6391: String?
  let voteAverage: Double?

  enum CodingKeys: String, CodingKey {
    case filePath = "file_path"
    case iso6391 = "iso_639_1"
    case voteAverage = "vote_average"
  }
}

struct TMDBVideos: Codable, Sendable {
  let results: [TMDBVideo]?
}

struct TMDBVideo: Codable, Sendable {
  let key: String?
  let site: String?
  let type: String?
  let official: Bool?
  let iso6391: String?

  enum CodingKeys: String, CodingKey {
    case key, site, type, official
    case iso6391 = "iso_639_1"
  }
}

struct TMDBKeywords: Codable, Sendable {
  let keywords: [TMDBNamed]?
  let results: [TMDBNamed]?

  var all: [TMDBNamed] {
    keywords ?? results ?? []
  }
}

struct TMDBExternalIDs: Codable, Sendable {
  let imdbId: String?

  enum CodingKeys: String, CodingKey {
    case imdbId = "imdb_id"
  }
}

struct TMDBReleaseDates: Codable, Sendable {
  let results: [TMDBReleaseCountry]?
}

struct TMDBReleaseCountry: Codable, Sendable {
  let iso31661: String?
  let releaseDates: [TMDBReleaseDate]?

  enum CodingKeys: String, CodingKey {
    case iso31661 = "iso_3166_1"
    case releaseDates = "release_dates"
  }
}

struct TMDBReleaseDate: Codable, Sendable {
  let certification: String?
  let type: Int?
}

struct TMDBContentRatings: Codable, Sendable {
  let results: [TMDBContentRating]?
}

struct TMDBContentRating: Codable, Sendable {
  let iso31661: String?
  let rating: String?

  enum CodingKeys: String, CodingKey {
    case iso31661 = "iso_3166_1"
    case rating
  }
}

struct TMDBEpisodeAir: Codable, Sendable {
  let airDate: String?
  let episodeNumber: Int?
  let seasonNumber: Int?
  let name: String?

  enum CodingKeys: String, CodingKey {
    case name
    case airDate = "air_date"
    case episodeNumber = "episode_number"
    case seasonNumber = "season_number"
  }
}

// MARK: - Season

struct TMDBSeasonDetails: Codable, Sendable {
  let seasonNumber: Int?
  let episodes: [TMDBSeasonEpisode]?

  enum CodingKeys: String, CodingKey {
    case episodes
    case seasonNumber = "season_number"
  }
}

struct TMDBSeasonEpisode: Codable, Sendable {
  let episodeNumber: Int?
  let name: String?
  let overview: String?
  let airDate: String?
  let runtime: Int?
  let stillPath: String?

  enum CodingKeys: String, CodingKey {
    case name, overview, runtime
    case episodeNumber = "episode_number"
    case airDate = "air_date"
    case stillPath = "still_path"
  }
}

// MARK: - Cached id mapping

struct TMDBResolvedID: Codable, Sendable {
  let tmdbId: Int
  let type: String
}

// MARK: - Person

struct TMDBPersonDetails: Codable, Sendable {
  let id: Int
  let name: String?
  let biography: String?
  let birthday: String?
  let placeOfBirth: String?
  let profilePath: String?
  let knownForDepartment: String?

  enum CodingKeys: String, CodingKey {
    case id, name, biography, birthday
    case placeOfBirth = "place_of_birth"
    case profilePath = "profile_path"
    case knownForDepartment = "known_for_department"
  }
}
