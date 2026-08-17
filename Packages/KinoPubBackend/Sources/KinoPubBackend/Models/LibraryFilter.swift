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

/// Hot/popular window for `/v1/items?period=`. Server-side (unlike rating/HD facets).
/// DESIGN: chip chrome in `LibraryFiltersBar` TBD — values are ready to send.
public enum CatalogPeriod: String, CaseIterable, Identifiable, Hashable {
  case day
  case week
  case month
  case year

  public var id: Self { self }

  /// Localization key for when the filter chrome lands.
  public var titleKey: String {
    switch self {
    case .day: return "Period_Day"
    case .week: return "Period_Week"
    case .month: return "Period_Month"
    case .year: return "Period_Year"
    }
  }
}

/// Everything the library listing filters on. `nil` means "any".
///
/// Rating / quality / AC3 facets are applied **client-side**. The mobile `/v1/items`
/// API only honors type/genre/country/year/sort/cast/director/`period` — `imdb` /
/// `kinopoisk` / `quality` / `conditions` query params are silently ignored (verified
/// by the dungeon-master-xx fork against the live API). Each `MediaItem` already carries
/// `imdbRating` / `kinopoiskRating` / `quality` / `ac3`, so we filter the page locally.
public struct LibraryFilter: Equatable, Hashable {
  public var contentType: MediaType?
  public var sort: MediaSortOrder
  public var genreID: Int?
  /// Several genres at once — `/v1/items` reads a comma as OR on `genre`. Set instead
  /// of `genreID` when asking "more like this" of a title filed under six of them.
  public var genreIDs: [Int] = []
  public var countryID: Int?
  public var years: YearRange?
  /// Set for a person's credits, which are the same listing narrowed to one name.
  public var person: MediaPerson?
  /// Popularity window (`day`/`week`/`month`/`year`) — sent server-side.
  public var period: CatalogPeriod?

  /// Minimum Kinopoisk rating (0…10). Applied client-side.
  public var kinopoiskMin: Double?
  /// Minimum IMDb rating (0…10). Applied client-side.
  public var imdbMin: Double?
  /// Keep items whose advertised height is ≥ 720. Applied client-side.
  public var wantHD: Bool
  /// Keep items whose advertised height is ≥ 2160. Applied client-side.
  public var want4K: Bool
  /// Drop items whose advertised height is ≥ 720. Applied client-side.
  public var withoutHD: Bool
  /// Keep items with `ac3 == 1`. Applied client-side.
  public var wantAC3: Bool

  public init(
    contentType: MediaType? = nil,
    sort: MediaSortOrder = .recentlyAdded,
    genreID: Int? = nil,
    genreIDs: [Int] = [],
    countryID: Int? = nil,
    years: YearRange? = nil,
    person: MediaPerson? = nil,
    period: CatalogPeriod? = nil,
    kinopoiskMin: Double? = nil,
    imdbMin: Double? = nil,
    wantHD: Bool = false,
    want4K: Bool = false,
    withoutHD: Bool = false,
    wantAC3: Bool = false
  ) {
    self.contentType = contentType
    self.sort = sort
    self.genreID = genreID
    self.genreIDs = genreIDs
    self.countryID = countryID
    self.years = years
    self.person = person
    self.period = period
    self.kinopoiskMin = kinopoiskMin
    self.imdbMin = imdbMin
    self.wantHD = wantHD
    self.want4K = want4K
    self.withoutHD = withoutHD
    self.wantAC3 = wantAC3
  }

  /// True when anything other than the default sort is in play.
  public var hasActiveFilters: Bool {
    contentType != nil
      || genreID != nil
      || !genreIDs.isEmpty
      || countryID != nil
      || years != nil
      || period != nil
      || hasClientSideFacets
  }

  /// Facets the server ignores — applied to each fetched page locally.
  public var hasClientSideFacets: Bool {
    (imdbMin ?? 0) > 0
      || (kinopoiskMin ?? 0) > 0
      || wantHD
      || withoutHD
      || want4K
      || wantAC3
  }

  /// Applies the client-side-only facets to a fetched item.
  public func clientSideMatches(_ item: MediaItem) -> Bool {
    if let imdbMin, imdbMin > 0, (item.imdbRating ?? 0) < imdbMin { return false }
    if let kinopoiskMin, kinopoiskMin > 0, (item.kinopoiskRating ?? 0) < kinopoiskMin { return false }
    if wantAC3, (item.ac3 ?? 0) != 1 { return false }
    if want4K, item.quality < 2160 { return false }
    if wantHD, item.quality < 720 { return false }
    if withoutHD, item.quality >= 720 { return false }
    return true
  }
}
