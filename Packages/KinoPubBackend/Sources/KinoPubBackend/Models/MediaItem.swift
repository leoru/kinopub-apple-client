//
//  MediaItem.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct MediaItem: Codable, Hashable {
  public let id: Int
  public let type: String
  public let subtype: String
  public let title: String
  public let year: Int
  public let cast: String
  public let director: String
  public let genres: [Country]
  public let countries: [Country]
  public let voice: String?
  public let duration: Duration
  public let langs: Int
  public let quality: Int
  public let plot: String
  public let imdb: Int?
  public let imdbRating: Double?
  public let imdbVotes: Int?
  public let kinopoisk: Int?
  public let kinopoiskRating: Double?
  public let kinopoiskVotes: Int?
  public let rating: Int
  public let ratingVotes: Int
  public let ratingPercentage: Double
  public let views: Int
  public let comments: Int
  public let posters: Posters
  public let trailer: Trailer?
  public let finished: Bool
  public let advert: Bool
  public let poorQuality: Bool
  public let createdAt: Int
  public let updatedAt: Int
  public let inWatchlist: Bool?
  public let subscribed: Bool?
  
  private enum CodingKeys: String, CodingKey {
    case id = "id"
    case type = "type"
    case subtype = "subtype"
    case title = "title"
    case year = "year"
    case cast = "cast"
    case director = "director"
    case genres = "genres"
    case countries = "countries"
    case voice = "voice"
    case duration = "duration"
    case langs = "langs"
    case quality = "quality"
    case plot = "plot"
    case imdb = "imdb"
    case imdbRating = "imdb_rating"
    case imdbVotes = "imdb_votes"
    case kinopoisk = "kinopoisk"
    case kinopoiskRating = "kinopoisk_rating"
    case kinopoiskVotes = "kinopoisk_votes"
    case rating = "rating"
    case ratingVotes = "rating_votes"
    case ratingPercentage = "rating_percentage"
    case views = "views"
    case comments = "comments"
    case posters = "posters"
    case trailer = "trailer"
    case finished = "finished"
    case advert = "advert"
    case poorQuality = "poor_quality"
    case createdAt = "created_at"
    case updatedAt = "updated_at"
    case inWatchlist = "in_watchlist"
    case subscribed = "subscribed"
  }
  
}

extension MediaItem: Identifiable { }
