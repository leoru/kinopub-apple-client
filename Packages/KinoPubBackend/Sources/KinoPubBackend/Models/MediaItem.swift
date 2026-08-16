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
  public let genres: [TypeClass]
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
  public let ac3: Int?
  public let bookmarks: [TypeClass]?
  public var seasons: [Season]?
  public let videos: [Video]?

  public init(
    id: Int,
    type: String,
    subtype: String,
    title: String,
    year: Int,
    cast: String,
    director: String,
    genres: [TypeClass],
    countries: [Country],
    voice: String?,
    duration: Duration,
    langs: Int,
    quality: Int,
    plot: String,
    imdb: Int?,
    imdbRating: Double?,
    imdbVotes: Int?,
    kinopoisk: Int?,
    kinopoiskRating: Double?,
    kinopoiskVotes: Int?,
    rating: Int,
    ratingVotes: Int,
    ratingPercentage: Double,
    views: Int,
    comments: Int,
    posters: Posters,
    trailer: Trailer?,
    finished: Bool,
    advert: Bool,
    poorQuality: Bool,
    createdAt: Int,
    updatedAt: Int,
    inWatchlist: Bool?,
    subscribed: Bool?,
    ac3: Int?,
    bookmarks: [TypeClass]?,
    seasons: [Season]?,
    videos: [Video]?
  ) {
    self.id = id
    self.type = type
    self.subtype = subtype
    self.title = title
    self.year = year
    self.cast = cast
    self.director = director
    self.genres = genres
    self.countries = countries
    self.voice = voice
    self.duration = duration
    self.langs = langs
    self.quality = quality
    self.plot = plot
    self.imdb = imdb
    self.imdbRating = imdbRating
    self.imdbVotes = imdbVotes
    self.kinopoisk = kinopoisk
    self.kinopoiskRating = kinopoiskRating
    self.kinopoiskVotes = kinopoiskVotes
    self.rating = rating
    self.ratingVotes = ratingVotes
    self.ratingPercentage = ratingPercentage
    self.views = views
    self.comments = comments
    self.posters = posters
    self.trailer = trailer
    self.finished = finished
    self.advert = advert
    self.poorQuality = poorQuality
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.inWatchlist = inWatchlist
    self.subscribed = subscribed
    self.ac3 = ac3
    self.bookmarks = bookmarks
    self.seasons = seasons
    self.videos = videos
  }

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
    case bookmarks = "bookmarks"
    case ac3 = "ac3"
    case seasons = "seasons"
    case videos = "videos"
  }

  /// Listing payloads sometimes send `null` for timestamps and other soft ints
  /// (`updated_at` on older credits). Soft fields default to zero so one bad
  /// value cannot blank an entire person/library page.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(Int.self, forKey: .id)
    type = try c.decode(String.self, forKey: .type)
    subtype = try c.decodeIfPresent(String.self, forKey: .subtype) ?? ""
    title = try c.decode(String.self, forKey: .title)
    year = try c.decodeIfPresent(Int.self, forKey: .year) ?? 0
    cast = try c.decodeIfPresent(String.self, forKey: .cast) ?? ""
    director = try c.decodeIfPresent(String.self, forKey: .director) ?? ""
    genres = try c.decodeIfPresent([TypeClass].self, forKey: .genres) ?? []
    countries = try c.decodeIfPresent([Country].self, forKey: .countries) ?? []
    voice = try c.decodeIfPresent(String.self, forKey: .voice)
    duration = try c.decode(Duration.self, forKey: .duration)
    langs = try c.decodeIfPresent(Int.self, forKey: .langs) ?? 0
    quality = try c.decodeIfPresent(Int.self, forKey: .quality) ?? 0
    plot = try c.decodeIfPresent(String.self, forKey: .plot) ?? ""
    imdb = try c.decodeIfPresent(Int.self, forKey: .imdb)
    imdbRating = try c.decodeIfPresent(Double.self, forKey: .imdbRating)
    imdbVotes = try c.decodeIfPresent(Int.self, forKey: .imdbVotes)
    kinopoisk = try c.decodeIfPresent(Int.self, forKey: .kinopoisk)
    kinopoiskRating = try c.decodeIfPresent(Double.self, forKey: .kinopoiskRating)
    kinopoiskVotes = try c.decodeIfPresent(Int.self, forKey: .kinopoiskVotes)
    rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 0
    ratingVotes = try c.decodeIfPresent(Int.self, forKey: .ratingVotes) ?? 0
    ratingPercentage = try c.decodeIfPresent(Double.self, forKey: .ratingPercentage) ?? 0
    views = try c.decodeIfPresent(Int.self, forKey: .views) ?? 0
    comments = try c.decodeIfPresent(Int.self, forKey: .comments) ?? 0
    posters = try c.decode(Posters.self, forKey: .posters)
    trailer = try c.decodeIfPresent(Trailer.self, forKey: .trailer)
    finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
    advert = try c.decodeIfPresent(Bool.self, forKey: .advert) ?? false
    poorQuality = try c.decodeIfPresent(Bool.self, forKey: .poorQuality) ?? false
    createdAt = try c.decodeIfPresent(Int.self, forKey: .createdAt) ?? 0
    updatedAt = try c.decodeIfPresent(Int.self, forKey: .updatedAt) ?? 0
    inWatchlist = try c.decodeIfPresent(Bool.self, forKey: .inWatchlist)
    subscribed = try c.decodeIfPresent(Bool.self, forKey: .subscribed)
    ac3 = try c.decodeIfPresent(Int.self, forKey: .ac3)
    bookmarks = try c.decodeIfPresent([TypeClass].self, forKey: .bookmarks)
    seasons = try c.decodeIfPresent([Season].self, forKey: .seasons)
    videos = try c.decodeIfPresent([Video].self, forKey: .videos)
  }
}

public extension MediaItem {
  /// Note: `seasons` is nil for films, so the nil default must be `true` here — the
  /// previous `?? false` reported every film as a series.
  var isSeries: Bool {
    !(seasons?.isEmpty ?? true)
  }

  /// What the primary button should offer, based on how far the user already got.
  var playbackAction: PlaybackAction {
    if isSeries {
      let episodes = (seasons ?? []).flatMap(\.episodes)
      guard !episodes.isEmpty else { return .play }
      if episodes.allSatisfy(\.isWatched) { return .playAgain }
      if episodes.contains(where: { $0.isWatched || $0.watchProgress.hasStarted }) { return .resume }
      return .play
    }

    guard let video = primaryVideo else { return .play }
    if video.isWatched { return .playAgain }
    return video.watchProgress.hasStarted ? .resume : .play
  }

  // MARK: - Versions of one film

  /// The API declares a film with several encodings this way. It is *not* what decides
  /// whether the versions rail appears — two `videos` are — but it is what the detail
  /// page suppresses in the tag strip, since the rail says the same thing better.
  var isMultiVersion: Bool {
    subtype.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "multi"
  }

  /// The same film encoded differently — 24 / 48 fps, colour / black-and-white,
  /// director's cut. **Empty unless there is more than one**, because a film with a
  /// single video has no version to choose between and a one-tile rail is noise.
  var playbackVariants: [PlaybackVariant] {
    guard !isSeries, let videos, videos.count > 1 else { return [] }
    return videos
      .sorted { $0.number < $1.number }
      .map { PlaybackVariant(video: $0, mediaId: id, movieTitle: localizedTitle) }
  }

  /// The version Play should open: the one already started but unfinished, else the
  /// first.
  ///
  /// 🔴 **Nothing about a film may read `videos.first`.** Everything did — files,
  /// subtitles, audio, resume point — so on item 124447 (24 fps / 48 fps) watching one
  /// and pressing Play resumed the *other* at a position that was not its own, and its
  /// subtitle list was the first entry's (55 tracks vs 0). Captured payload and the full
  /// shape: `docs/providers/kinopub/video.md`, fixture + `MultiVersionItemTests`.
  var primaryVideo: Video? {
    guard let videos, !videos.isEmpty else { return nil }
    if let inProgress = videos.first(where: { $0.watchProgress.hasStarted && !$0.isWatchedToEnd }) {
      return inProgress
    }
    return videos.first
  }

  /// The variant Play should open, when there is a choice. Nil for a single-video film —
  /// the caller plays the `MediaItem` itself, as it always did.
  var primaryVariant: PlaybackVariant? {
    guard !playbackVariants.isEmpty, let video = primaryVideo else { return nil }
    return PlaybackVariant(video: video, mediaId: id, movieTitle: localizedTitle)
  }
}

/// The three states the primary action on a detail page can be in.
public enum PlaybackAction: String {
  case play
  case resume
  case playAgain

  /// Localization keys, resolved by the app.
  public var titleKey: String {
    switch self {
    case .play: return "Play"
    case .resume: return "Continue"
    case .playAgain: return "Play Again"
    }
  }
}

// MARK: - All series files list

public extension MediaItem {
  
  var downloadableItems: [DownloadableMediaItem] {
    return seasons?.flatMap({ season in
      season.episodes.map({ episode in
        DownloadableMediaItem(name: "S\(season.number)E\(episode.number)",
                              files: episode.files,
                              mediaItem: self,
                              watchingMetadata: WatchingMetadata(id: episode.id, video: episode.number, season: season.number))
      })
    }) ?? []
  }
  
}

// MARK: - Downloadable url

public extension MediaItem {

  var downloadableURL: URL {
    URL(string: videos?.last?.files.first?.url.http ?? "")!
  }
  
  var watchableURL: URL {
    URL(string: primaryVideo?.files.first?.url.hls4 ?? "")!
  }
  
}

public extension MediaItem {
  static func mock(id: Int = 1) -> MediaItem {
    MediaItem(id: id, type: "test",
              subtype: "test",
              title: "Стражи Галактики. Часть 3 / Guardians of the Galaxy Vol. 3",
              year: 2023,
              cast: "Крис Пратт, Зои Салдана, Дэйв Батиста, Карен Гиллан, Пом Клементьефф, Вин Дизель, Брэдли Купер, Уилл Поултер, Шон Ганн, Чукуди Ивуджи, Линда Карделлини, Нэйтан Филлион, Сильвестр Сталлоне",
              director: "Джеймс Ганн",
              genres: [
                TypeClass(id: 1, title: "Comedy", shortTitle: nil),
                TypeClass(id: 2, title: "Action", shortTitle: nil),
                TypeClass(id: 3, title: "Fantastic", shortTitle: nil),
                TypeClass(id: 4, title: "Adventure", shortTitle: nil)
              ],
              countries: [
                Country(id: 1, title: "USA"),
                Country(id: 1, title: "France"),
                Country(id: 1, title: "Canada"),
                Country(id: 1, title: "New Zeland")
              ],
              voice: "Русский. Дубляж. Red Head Sound, Русский. Дубляж. Лицензия",
              duration: Duration(average: 0, total: 230),
              langs: 0,
              quality: 0,
              plot: "После финальных разборок с Таносом стражи успели прийти в себя, окрепнуть и даже разместить собственный штаб в далёкой-далёкой галактике. Стабильное настоящее, впрочем, не мешает Питеру Квиллу всё чаще возвращаться в прошлое, заливать разбитое гибелью Гаморы сердце дешёвым алкоголем и всячески страдать. Размеренные будни героев, число которых увеличилось за счёт помощника Йонду Краглина и советской собаки Космо, нарушает Адам Уорлок, наёмник некоего Верховного эволюционера. Много лет назад Эволюционер создал генетически модифицированного енота Ракету и сейчас намерен во что бы то ни стало вернуть своё творение обратно.",
              imdb: 0,
              imdbRating: 8.100,
              imdbVotes: 0,
              kinopoisk: 0,
              kinopoiskRating: 8.300,
              kinopoiskVotes: 0,
              rating: 0,
              ratingVotes: 0,
              ratingPercentage: 0,
              views: 730000,
              comments: 0,
              posters: Posters(small: "", medium: "", big: "", wide: ""),
              trailer: nil,
              finished: true,
              advert: true,
              poorQuality: false,
              createdAt: 0,
              updatedAt: 0,
              inWatchlist: false,
              subscribed: false,
              ac3: nil,
              bookmarks: nil,
              seasons: nil,
              videos: nil)
  }
}

extension MediaItem: Identifiable { }

public extension MediaItem {
  /// When it came out and how long it runs.
  private var releaseParts: [String] {
    var parts: [String] = []
    if year > 0 { parts.append("\(year)") }
    if isSeries, let seasons {
      // `duration.total` sums every episode, which reads as a nonsense runtime for a
      // series — season count is what the Apple TV app shows.
      parts.append("\(seasons.count) \(seasons.count == 1 ? "season" : "seasons")")
    } else {
      // …and it sums every *version* for a multi-version film, which is the same
      // nonsense one level down: item 124447 ships 24 fps and 48 fps at 8634 s each and
      // reports `total: 17268`, so the page said 4 h 48 min for a 2 h 24 min film.
      // `average` is the runtime of the film; `total` is the runtime of the payload.
      let seconds = playbackVariants.isEmpty ? duration.total : duration.average
      let formatted = Duration.compact(seconds: Int(seconds))
      if !formatted.isEmpty { parts.append(formatted) }
    }
    return parts
  }

  /// "2025 · 1 h 55 min · Боевик, Драма · Япония" — everything about a title in one
  /// line, for the home screen's focus preview.
  var metadataLine: String {
    var parts = releaseParts
    let genres = genres.compactMap(\.title).prefix(2)
    if !genres.isEmpty { parts.append(genres.joined(separator: ", ")) }
    if let country = countries.first?.title { parts.append(country) }
    return parts.joined(separator: " · ")
  }

  /// "2025 · 1 h 55 min" — when and how long, nothing else. The item page's hero
  /// metadata row carries the scores and capability chips beside it, and genres and
  /// country sit with the cast under the synopsis instead.
  var releaseLine: String {
    releaseParts.joined(separator: " · ")
  }

  var originalTitle: String {
    title.split(separator: "/").last?.trimmingCharacters(in: .whitespaces) ?? title
  }

  var localizedTitle: String {
    title.split(separator: "/").first?.trimmingCharacters(in: .whitespaces) ?? title
  }
}

/// All of this reads `primaryVideo`, not `videos.first`: on a multi-version film those
/// are different videos as soon as the viewer has started one of them.
extension MediaItem: PlayableItem {
  public var files: [FileInfo] {
    primaryVideo?.files ?? []
  }

  public var metadata: WatchingMetadata {
    WatchingMetadata(id: id, video: primaryVideo?.number, season: nil)
  }

  public var subtitles: [Subtitle] {
    primaryVideo?.subtitles ?? []
  }

  public var audioTracks: [AudioTrackInfo] {
    AudioTracks.catalog(primaryVideo?.audios ?? [])
  }
}
