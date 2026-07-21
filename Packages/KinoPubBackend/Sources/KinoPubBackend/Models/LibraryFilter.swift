//
//  LibraryFilter.swift
//
//

import Foundation

/// How the library listing is sorted.
///
/// `kinopoisk_rating` and `imdb_rating` are absent from the published docs but the
/// service accepts them and orders correctly — verified against live responses.
public enum MediaSortOrder: String, CaseIterable, Identifiable, Hashable {
  case recentlyAdded
  case recentlyUpdated
  case views
  case title
  case year
  case kinopoiskRating
  case imdbRating

  public var id: Self { self }

  /// The `sort` parameter. A `-` prefix means descending.
  public var apiValue: String {
    switch self {
    case .recentlyAdded: return "-created"
    case .recentlyUpdated: return "-updated"
    case .views: return "-views"
    case .title: return "title"
    case .year: return "-year"
    case .kinopoiskRating: return "-kinopoisk_rating"
    case .imdbRating: return "-imdb_rating"
    }
  }

  /// Localization key.
  public var titleKey: String {
    switch self {
    case .recentlyAdded: return "Sort_RecentlyAdded"
    case .recentlyUpdated: return "Sort_RecentlyUpdated"
    case .views: return "Sort_Views"
    case .title: return "Sort_Title"
    case .year: return "Sort_Year"
    case .kinopoiskRating: return "Sort_KinopoiskRating"
    case .imdbRating: return "Sort_ImdbRating"
    }
  }
}

/// A release-year window. Decades rather than a free range: a two-ended numeric
/// picker is miserable to drive with a remote.
public struct YearRange: Identifiable, Hashable {
  public let from: Int
  public let to: Int

  public var id: String { "\(from)-\(to)" }

  public init(from: Int, to: Int) {
    self.from = from
    self.to = to
  }

  /// "1990-1999", the format the `year` parameter takes.
  public var apiValue: String { "\(from)-\(to)" }

  public var title: String {
    from == to ? "\(from)" : "\(from)–\(to)"
  }

  /// The current decade down to the 1950s, newest first.
  public static func decades(upTo year: Int) -> [YearRange] {
    let currentDecade = (year / 10) * 10
    return stride(from: currentDecade, through: 1950, by: -10).map {
      YearRange(from: $0, to: $0 + 9)
    }
  }
}

/// Everything the library listing filters on. `nil` means "any".
public struct LibraryFilter: Equatable, Hashable {
  public var contentType: MediaType?
  public var sort: MediaSortOrder
  public var genreID: Int?
  public var countryID: Int?
  public var years: YearRange?

  public init(contentType: MediaType? = nil,
              sort: MediaSortOrder = .recentlyAdded,
              genreID: Int? = nil,
              countryID: Int? = nil,
              years: YearRange? = nil) {
    self.contentType = contentType
    self.sort = sort
    self.genreID = genreID
    self.countryID = countryID
    self.years = years
  }

  /// True when anything other than the default sort is in play.
  public var hasActiveFilters: Bool {
    contentType != nil || genreID != nil || countryID != nil || years != nil
  }
}
