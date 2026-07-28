import Foundation

/// Response shapes for kinopoiskapiunofficial.tech. Field names/shapes verified
/// against live responses this session (details, staff, awards, images, facts) —
/// the published docs are thin, so these are pinned to what the service actually
/// returns rather than the schema page.

struct KinopoiskFilmDetails: Decodable {
  let kinopoiskId: Int
  let nameRu: String?
  let nameEn: String?
  let nameOriginal: String?
  let posterUrl: String?
  let posterUrlPreview: String?
  let coverUrl: String?
  let logoUrl: String?
  let ratingKinopoisk: Double?
  let ratingKinopoiskVoteCount: Int?
  let ratingImdb: Double?
  let ratingImdbVoteCount: Int?
  let webUrl: String?
  let year: Int?
  let filmLength: Int?
  let slogan: String?
  let description: String?
  let shortDescription: String?
  let type: String?
  let ratingMpaa: String?
  let ratingAgeLimits: String?
  let countries: [KinopoiskCountry]?
  let genres: [KinopoiskGenre]?
  let serial: Bool?
}

struct KinopoiskCountry: Decodable { let country: String? }
struct KinopoiskGenre: Decodable { let genre: String? }

/// `/api/v1/staff?filmId=` — flat array, not wrapped.
struct KinopoiskStaffMember: Decodable {
  let staffId: Int
  let nameRu: String?
  let nameEn: String?
  /// Actor rows carry `"Actor Name — Character Name"`; other roles are usually nil.
  let description: String?
  let posterUrl: String?
  let professionText: String?
  let professionKey: String?
}

struct KinopoiskAwardsResponse: Decodable {
  let total: Int
  let items: [KinopoiskAward]
}

struct KinopoiskAward: Decodable {
  let name: String?
  let win: Bool?
  let nominationName: String?
  let year: Int?
}

struct KinopoiskImagesResponse: Decodable {
  let total: Int
  let totalPages: Int
  let items: [KinopoiskImage]
}

struct KinopoiskImage: Decodable {
  let imageUrl: String?
  let previewUrl: String?
}

struct KinopoiskFactsResponse: Decodable {
  let total: Int
  let items: [KinopoiskFact]
}

struct KinopoiskFact: Decodable {
  /// Carries embedded HTML (`<a href=...>`, `&#160;`) — strip before display.
  let text: String?
  let type: String?
  let spoiler: Bool?
}
