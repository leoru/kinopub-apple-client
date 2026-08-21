//
//  MediaCardView.swift
//
//

import Foundation
import SwiftUI
import KinoPubBackend

/// What a single-click / Select on the card does.
public enum MediaCardPrimaryAction: String, Codable, Hashable, Sendable {
  /// Push the title detail page (default catalog posters).
  case openDetail
  /// Fetch + open the player at the resume point (Continue Watching).
  case play
}

/// Icon + value shown under a card title (collection watchers / views, etc.).
public struct MediaCardCaptionStat: Hashable, Codable, Sendable {
  public let systemImage: String
  public let value: String

  public init(systemImage: String, value: String) {
    self.systemImage = systemImage
    self.value = value
  }
}

/// Everything a poster card needs to draw itself, so rows can be built from any
/// endpoint's payload rather than only from a full `MediaItem`.
public struct MediaCard: Identifiable, Hashable, Codable {
  public let id: Int
  public let posterURL: String
  public let title: String
  public let subtitle: String?
  /// When this was watched, for history surfaces. **On the card, not beside it**: the
  /// card is what `ContentStore` snapshots, so a date kept in a parallel map is lost
  /// the moment page 1 is served from cache — which is what put a warm-cache history
  /// list entirely into the "Earlier" section.
  public let watchedAt: Date?
  /// External catalogue scores. Prefer this over pulling fields off `MediaItem`.
  public let scores: MediaScores

  /// Convenience for call sites / Codable that still speak in loose doubles.
  public var imdbRating: Double? { scores.imdb }
  public var kinopoiskRating: Double? { scores.kinopoisk }

  /// The combined score shown on the poster, or nil when neither source rated it.
  public var rating: Rating? { scores.aggregate }
  /// `WatchProgress.resumeFraction` — 0…1 while this video is in progress, nil
  /// when unwatched or already finished. Do not re-threshold it in the view.
  public let progress: Double?
  public let badge: String?

  /// Wide artwork for the page behind the card, shown while it holds focus. Nil
  /// falls back to whatever the card itself draws.
  public let backdropURL: String?

  /// "2025 · 1 h 55 min · Боевик" — shown in the focus preview, not on the card.
  public let metaLine: String?
  /// The plot, for the focus preview.
  public let overview: String?

  /// When set the card renders wide instead of as a poster — used by Continue
  /// Watching, where the artwork is an episode still.
  public let landscapeImageURL: String?
  /// Overlaid on a landscape card, e.g. "S2, E5 · 42 min".
  public let overlayLabel: String?

  /// The title this card belongs to. For an episode card this is the series id;
  /// for a normal poster it matches `id`.
  public let itemID: Int
  /// Episode/video number for `/v1/watching/toggle`. Nil when the card is just a poster.
  public let video: Int?
  /// Season number for series episodes. Nil for films.
  public let season: Int?
  /// History media id for `/v1/history/clear-for-media`. Nil clears the whole item.
  public let mediaID: Int?
  /// Whether this video is already marked watched — drives the context-menu label.
  public let isWatched: Bool
  /// True for serials, so the context menu can say "Go to Show" rather than "Go to Movie".
  public let isSeries: Bool
  /// Title appears in `/v1/history` — context menu can offer Browse History.
  public let isInHistory: Bool
  /// Title is on the user's watchlist — context menu can offer Browse Watchlist.
  public let isInWatchlist: Bool
  /// Item-level 4K / HDR when known from the catalogue payload (not device caps).
  public let is4K: Bool
  public let isHDR: Bool
  public let isHD: Bool
  public let is3D: Bool
  public let hasClosedCaptions: Bool
  /// Release year when known from the catalogue.
  public let year: Int?
  /// Runtime in seconds (film total, or episode when the card is an episode still).
  public let durationSeconds: Int?
  /// One or two genre titles for the caption meta row.
  public let genreLine: String?
  /// First production country for the caption meta row.
  public let countryLine: String?
  /// Title sits in at least one bookmark folder (not the watchlist flag).
  public let isBookmarked: Bool
  /// Folder ids from `MediaItem.bookmarks` when the payload carried them. Empty when
  /// unknown — local `BookmarkMembershipStore` overlays toggles on top.
  public let bookmarkFolderIDs: [Int]
  /// Single-click / Select target. Continue Watching uses `.play`; History stays detail for now.
  public let primaryAction: MediaCardPrimaryAction
  /// When true, Select opens a curated collection rather than a media title — Home /
  /// Collections grids use this so collection ids are not mistaken for item ids.
  public let opensCollection: Bool
  /// Icon + counter stack under the title (watchers / views on collection covers).
  public let captionStats: [MediaCardCaptionStat]

  public var isLandscape: Bool { landscapeImageURL != nil }

  /// What the focus backdrop draws: the wide artwork where the payload carried one,
  /// the card's own image otherwise.
  public var backdropImageURL: String {
    backdropURL ?? landscapeImageURL ?? posterURL
  }

  /// Whether a long-press  can toggle watched for this card (needs a video target).
  public var canToggleWatched: Bool { video != nil }

  /// Score for the plaque / caption, honouring the user's source preference.
  public func displayRating(source: MediaCardRatingSource) -> Rating? {
    scores.selecting(source).aggregate
  }

  /// Scores filtered to the user's source preference (for `MediaScoresView`).
  public func displayScores(source: MediaCardRatingSource) -> MediaScores {
    scores.selecting(source)
  }

  /// Compact runtime for captions when `durationSeconds` is set.
  public var durationLabel: String? {
    guard let durationSeconds, durationSeconds >= 60 else { return nil }
    let label = Duration.compact(seconds: durationSeconds)
    return label.isEmpty ? nil : label
  }

  public init(id: Int,
              posterURL: String,
              title: String,
              subtitle: String? = nil,
              watchedAt: Date? = nil,
              scores: MediaScores? = nil,
              imdbRating: Double? = nil,
              imdbVotes: Int? = nil,
              kinopoiskRating: Double? = nil,
              kinopoiskVotes: Int? = nil,
              progress: Double? = nil,
              badge: String? = nil,
              backdropURL: String? = nil,
              metaLine: String? = nil,
              overview: String? = nil,
              landscapeImageURL: String? = nil,
              overlayLabel: String? = nil,
              itemID: Int? = nil,
              video: Int? = nil,
              season: Int? = nil,
              mediaID: Int? = nil,
              isWatched: Bool = false,
              isSeries: Bool = false,
              isInHistory: Bool = false,
              isInWatchlist: Bool = false,
              is4K: Bool = false,
              isHDR: Bool = false,
              isHD: Bool = false,
              is3D: Bool = false,
              hasClosedCaptions: Bool = false,
              year: Int? = nil,
              durationSeconds: Int? = nil,
              genreLine: String? = nil,
              countryLine: String? = nil,
              isBookmarked: Bool = false,
              bookmarkFolderIDs: [Int] = [],
              primaryAction: MediaCardPrimaryAction = .openDetail,
              opensCollection: Bool = false,
              captionStats: [MediaCardCaptionStat] = []) {
    self.id = id
    self.posterURL = posterURL
    self.title = title
    self.subtitle = subtitle
    self.watchedAt = watchedAt
    self.scores = scores ?? MediaScores(
      imdb: imdbRating,
      imdbVotes: imdbVotes,
      kinopoisk: kinopoiskRating,
      kinopoiskVotes: kinopoiskVotes
    )
    self.progress = progress
    self.badge = badge
    self.backdropURL = backdropURL
    self.metaLine = metaLine
    self.overview = overview
    self.landscapeImageURL = landscapeImageURL
    self.overlayLabel = overlayLabel
    self.itemID = itemID ?? id
    self.video = video
    self.season = season
    self.mediaID = mediaID
    self.isWatched = isWatched
    self.isSeries = isSeries
    self.isInHistory = isInHistory
    self.isInWatchlist = isInWatchlist
    self.is4K = is4K
    self.isHDR = isHDR
    self.isHD = isHD
    self.is3D = is3D
    self.hasClosedCaptions = hasClosedCaptions
    self.year = year
    self.durationSeconds = durationSeconds
    self.genreLine = genreLine
    self.countryLine = countryLine
    self.isBookmarked = isBookmarked
    self.bookmarkFolderIDs = bookmarkFolderIDs
    self.primaryAction = primaryAction
    self.opensCollection = opensCollection
    self.captionStats = captionStats
  }

  /// Continue Watching paint-time overlay: progress / offered S/E change without
  /// rebuilding the rest of the card (artwork, badges, identity).
  public func withContinueWatching(progress: Double?,
                                   season: Int?,
                                   video: Int?,
                                   overlayLabel: String?,
                                   durationSeconds: Int? = nil) -> MediaCard {
    MediaCard(id: id,
              posterURL: posterURL,
              title: title,
              subtitle: subtitle,
              watchedAt: watchedAt,
              scores: scores,
              progress: progress,
              badge: badge,
              backdropURL: backdropURL,
              metaLine: overlayLabel ?? metaLine,
              overview: overview,
              landscapeImageURL: landscapeImageURL,
              overlayLabel: overlayLabel,
              itemID: itemID,
              video: video,
              season: season,
              mediaID: mediaID,
              isWatched: isWatched,
              isSeries: isSeries,
              isInHistory: isInHistory,
              isInWatchlist: isInWatchlist,
              is4K: is4K,
              isHDR: isHDR,
              isHD: isHD,
              is3D: is3D,
              hasClosedCaptions: hasClosedCaptions,
              year: year,
              durationSeconds: durationSeconds ?? self.durationSeconds,
              genreLine: genreLine,
              countryLine: countryLine,
              isBookmarked: isBookmarked,
              bookmarkFolderIDs: bookmarkFolderIDs,
              primaryAction: primaryAction,
              opensCollection: opensCollection,
              captionStats: captionStats)
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(Int.self, forKey: .id)
    posterURL = try c.decode(String.self, forKey: .posterURL)
    title = try c.decode(String.self, forKey: .title)
    subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
    watchedAt = try c.decodeIfPresent(Date.self, forKey: .watchedAt)
    scores = MediaScores(
      imdb: try c.decodeIfPresent(Double.self, forKey: .imdbRating),
      imdbVotes: try c.decodeIfPresent(Int.self, forKey: .imdbVotes),
      kinopoisk: try c.decodeIfPresent(Double.self, forKey: .kinopoiskRating),
      kinopoiskVotes: try c.decodeIfPresent(Int.self, forKey: .kinopoiskVotes)
    )
    progress = try c.decodeIfPresent(Double.self, forKey: .progress)
    badge = try c.decodeIfPresent(String.self, forKey: .badge)
    backdropURL = try c.decodeIfPresent(String.self, forKey: .backdropURL)
    metaLine = try c.decodeIfPresent(String.self, forKey: .metaLine)
    overview = try c.decodeIfPresent(String.self, forKey: .overview)
    landscapeImageURL = try c.decodeIfPresent(String.self, forKey: .landscapeImageURL)
    overlayLabel = try c.decodeIfPresent(String.self, forKey: .overlayLabel)
    itemID = try c.decodeIfPresent(Int.self, forKey: .itemID) ?? id
    video = try c.decodeIfPresent(Int.self, forKey: .video)
    season = try c.decodeIfPresent(Int.self, forKey: .season)
    mediaID = try c.decodeIfPresent(Int.self, forKey: .mediaID)
    isWatched = try c.decodeIfPresent(Bool.self, forKey: .isWatched) ?? false
    isSeries = try c.decodeIfPresent(Bool.self, forKey: .isSeries) ?? false
    isInHistory = try c.decodeIfPresent(Bool.self, forKey: .isInHistory) ?? false
    isInWatchlist = try c.decodeIfPresent(Bool.self, forKey: .isInWatchlist) ?? false
    is4K = try c.decodeIfPresent(Bool.self, forKey: .is4K) ?? false
    isHDR = try c.decodeIfPresent(Bool.self, forKey: .isHDR) ?? false
    isHD = try c.decodeIfPresent(Bool.self, forKey: .isHD) ?? false
    is3D = try c.decodeIfPresent(Bool.self, forKey: .is3D) ?? false
    hasClosedCaptions = try c.decodeIfPresent(Bool.self, forKey: .hasClosedCaptions) ?? false
    year = try c.decodeIfPresent(Int.self, forKey: .year)
    durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds)
    genreLine = try c.decodeIfPresent(String.self, forKey: .genreLine)
    countryLine = try c.decodeIfPresent(String.self, forKey: .countryLine)
    isBookmarked = try c.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
    bookmarkFolderIDs = try c.decodeIfPresent([Int].self, forKey: .bookmarkFolderIDs) ?? []
    // Old row snapshots omit this key — keep opening detail until the next CW fetch.
    primaryAction = try c.decodeIfPresent(MediaCardPrimaryAction.self, forKey: .primaryAction)
      ?? .openDetail
    opensCollection = try c.decodeIfPresent(Bool.self, forKey: .opensCollection) ?? false
    captionStats = try c.decodeIfPresent([MediaCardCaptionStat].self, forKey: .captionStats) ?? []
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(posterURL, forKey: .posterURL)
    try c.encode(title, forKey: .title)
    try c.encodeIfPresent(subtitle, forKey: .subtitle)
    try c.encodeIfPresent(watchedAt, forKey: .watchedAt)
    try c.encodeIfPresent(scores.imdb, forKey: .imdbRating)
    try c.encodeIfPresent(scores.imdbVotes, forKey: .imdbVotes)
    try c.encodeIfPresent(scores.kinopoisk, forKey: .kinopoiskRating)
    try c.encodeIfPresent(scores.kinopoiskVotes, forKey: .kinopoiskVotes)
    try c.encodeIfPresent(progress, forKey: .progress)
    try c.encodeIfPresent(badge, forKey: .badge)
    try c.encodeIfPresent(backdropURL, forKey: .backdropURL)
    try c.encodeIfPresent(metaLine, forKey: .metaLine)
    try c.encodeIfPresent(overview, forKey: .overview)
    try c.encodeIfPresent(landscapeImageURL, forKey: .landscapeImageURL)
    try c.encodeIfPresent(overlayLabel, forKey: .overlayLabel)
    try c.encode(itemID, forKey: .itemID)
    try c.encodeIfPresent(video, forKey: .video)
    try c.encodeIfPresent(season, forKey: .season)
    try c.encodeIfPresent(mediaID, forKey: .mediaID)
    try c.encode(isWatched, forKey: .isWatched)
    try c.encode(isSeries, forKey: .isSeries)
    try c.encode(isInHistory, forKey: .isInHistory)
    try c.encode(isInWatchlist, forKey: .isInWatchlist)
    try c.encode(is4K, forKey: .is4K)
    try c.encode(isHDR, forKey: .isHDR)
    try c.encode(isHD, forKey: .isHD)
    try c.encode(is3D, forKey: .is3D)
    try c.encode(hasClosedCaptions, forKey: .hasClosedCaptions)
    try c.encodeIfPresent(year, forKey: .year)
    try c.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
    try c.encodeIfPresent(genreLine, forKey: .genreLine)
    try c.encodeIfPresent(countryLine, forKey: .countryLine)
    try c.encode(isBookmarked, forKey: .isBookmarked)
    try c.encode(bookmarkFolderIDs, forKey: .bookmarkFolderIDs)
    try c.encode(primaryAction, forKey: .primaryAction)
    try c.encode(opensCollection, forKey: .opensCollection)
    try c.encode(captionStats, forKey: .captionStats)
  }

  private enum CodingKeys: String, CodingKey {
    case id, posterURL, title, subtitle, watchedAt, imdbRating, imdbVotes, kinopoiskRating, kinopoiskVotes
    case progress, badge, backdropURL, metaLine, overview
    case landscapeImageURL, overlayLabel, itemID, video, season, mediaID
    case isWatched, isSeries, isInHistory, isInWatchlist, is4K, isHDR
    case isHD, is3D, hasClosedCaptions, year, durationSeconds
    case genreLine, countryLine, isBookmarked, bookmarkFolderIDs, primaryAction
    case opensCollection, captionStats
  }
}

public extension MediaCard {
  /// The standard mapping from a catalog item, so grids and rows draw the same card.
  init(_ item: MediaItem) {
    let badges = MediaCapabilityBadges.from(item: item)
    // Prefer a real API `wide`, else the derived `/wide/` path. Do not fold `big` into
    // backdropURL — HomeBanner tries wide → big → medium so a 404'd derivation still
    // paints (detail payloads often have a working `wide`; catalogue lists often don't).
    let wide = item.posters.wide.flatMap { $0.isEmpty ? nil : $0 }
    let genres = item.genres.compactMap(\.title).prefix(2)
    let durationSeconds: Int? = {
      if item.isSeries { return nil }
      let total = Int(item.duration.total)
      return total >= 60 ? total : nil
    }()
    let bookmarkFolderIDs = (item.bookmarks ?? []).map(\.id)
    self.init(id: item.id,
              posterURL: item.posters.medium,
              title: item.localizedTitle,
              subtitle: item.originalTitle,
              scores: MediaScores(item),
              backdropURL: wide ?? item.posters.wideURL,
              metaLine: item.metadataLine,
              overview: item.plot,
              isSeries: item.isSeries,
              isInWatchlist: item.inWatchlist ?? false,
              is4K: badges.is4K,
              isHDR: badges.isHDR,
              isHD: badges.isHD,
              is3D: badges.is3D,
              hasClosedCaptions: badges.hasClosedCaptions,
              year: item.year > 0 ? item.year : nil,
              durationSeconds: durationSeconds,
              genreLine: genres.isEmpty ? nil : genres.joined(separator: ", "),
              countryLine: item.countries.first?.title,
              isBookmarked: !bookmarkFolderIDs.isEmpty,
              bookmarkFolderIDs: bookmarkFolderIDs)
  }
}

/// Where a card's name is drawn, if anywhere.
public enum MediaCardCaption {
  /// Never — the screen names the focused item somewhere else, as the home rows do
  /// in their preview.
  case none
  /// Only while the card holds focus, over space kept free for it so the grid does
  /// not shift as focus moves. What a grid with no preview of its own uses.
  case onFocus
  /// Always, for platforms with no focus at all.
  case always
}

/// Poster or landscape card. Width comes from the parent (`containerRelativeFrame` /
/// grid column); height from `CardAspect`. Landscape cards follow the episode-rail
/// layout: play glyph + progress on the still, title / meta in the caption below —
/// no ⋯ overflow control on the card (long-press context menu only).
///
/// Behavioural identity: same focus animation, caption reveal, progress semantics,
/// watched treatment and existing badge slots; only aspect and which slots have
/// content differ. New badge slots (editorial awards etc.) wait on design (D10).
public struct MediaCardView: View {

  private let card: MediaCard
  private let caption: MediaCardCaption
  private let playChromeStyle: LandscapePlayChromeStyle
  /// When true, play chrome stays visible (previews / VariantGallery).
  private let forcePlayChrome: Bool

  public init(card: MediaCard,
              caption: MediaCardCaption = .always,
              playChromeStyle: LandscapePlayChromeStyle = .glass,
              forcePlayChrome: Bool = false) {
    self.card = card
    self.caption = caption
    self.playChromeStyle = playChromeStyle
    self.forcePlayChrome = forcePlayChrome
  }

  @Environment(\.isFocused) private var cardFocused
#if os(macOS)
  @State private var isHovered = false
#endif

  /// A watched card's artwork sits dimmed, and on macOS hovering it restores it to full.
  /// `isHovered` only exists there — there is no pointer on tvOS or iOS — so the dim is
  /// simply constant off macOS rather than reading a state that does not compile.
  private var watchedArtworkOpacity: Double {
    guard dimsWatchedArtwork else { return 1 }
#if os(macOS)
    return isHovered ? 1 : 0.5
#else
    return 0.5
#endif
  }
  /// The artwork's own width, so its height is derived rather than negotiated. Nil for
  /// exactly one layout pass; `frame(height: nil)` leaves the natural size meanwhile.
  @State private var artworkWidth: CGFloat?

  @AppStorage(MediaCardDisplayPreferences.ratingPlacementKey)
  private var ratingPlacementRaw = MediaCardDisplayPreferences.defaultRatingPlacement.rawValue
  @AppStorage(MediaCardDisplayPreferences.ratingSourceKey)
  private var ratingSourceRaw = MediaCardDisplayPreferences.defaultRatingSource.rawValue
  @AppStorage(MediaCardDisplayPreferences.capabilityPlacementKey)
  private var capabilityPlacementRaw = MediaCardDisplayPreferences.defaultCapabilityPlacement.rawValue
  @AppStorage(MediaCardDisplayPreferences.show4KKey)
  private var show4K = MediaCardDisplayPreferences.defaultShow4K
  @AppStorage(MediaCardDisplayPreferences.showHDRKey)
  private var showHDR = MediaCardDisplayPreferences.defaultShowHDR
  @AppStorage(MediaCardDisplayPreferences.showHDKey)
  private var showHD = MediaCardDisplayPreferences.defaultShowHD
  @AppStorage(MediaCardDisplayPreferences.show3DKey)
  private var show3D = MediaCardDisplayPreferences.defaultShow3D
  @AppStorage(MediaCardDisplayPreferences.showCCKey)
  private var showCC = MediaCardDisplayPreferences.defaultShowCC
  @AppStorage(MediaCardDisplayPreferences.editorialPlacementKey)
  private var editorialPlacementRaw = MediaCardDisplayPreferences.defaultEditorialPlacement.rawValue
  @AppStorage(MediaCardDisplayPreferences.showOriginalTitleKey)
  private var showOriginalTitle = MediaCardDisplayPreferences.defaultShowOriginalTitle
  @AppStorage(MediaCardDisplayPreferences.showYearKey)
  private var showYear = MediaCardDisplayPreferences.defaultShowYear
  @AppStorage(MediaCardDisplayPreferences.showDurationKey)
  private var showDuration = MediaCardDisplayPreferences.defaultShowDuration
  @AppStorage(MediaCardDisplayPreferences.showGenreKey)
  private var showGenre = MediaCardDisplayPreferences.defaultShowGenre
  @AppStorage(MediaCardDisplayPreferences.showCountryKey)
  private var showCountry = MediaCardDisplayPreferences.defaultShowCountry
  @AppStorage(MediaCardDisplayPreferences.showBookmarkSymbolKey)
  private var showBookmarkSymbol = MediaCardDisplayPreferences.defaultShowBookmarkSymbol
  @AppStorage(MediaCardDisplayPreferences.progressVisibilityKey)
  private var progressVisibilityRaw = MediaCardDisplayPreferences.defaultProgressVisibility.rawValue
  @AppStorage(MediaCardDisplayPreferences.watchedStyleKey)
  private var watchedStyleRaw = MediaCardDisplayPreferences.defaultWatchedStyle.rawValue

  private var ratingPlacement: MediaCardChromePlacement {
    MediaCardChromePlacement(rawValue: ratingPlacementRaw)
      ?? MediaCardDisplayPreferences.defaultRatingPlacement
  }
  private var ratingSource: MediaCardRatingSource {
    // With the aggregate off there is no source picker in Settings either, so every
    // card shows whatever it has, each score under its own logo.
    guard RatingFeature.combinedEnabled else { return .combined }
    return MediaCardRatingSource(rawValue: ratingSourceRaw)
      ?? MediaCardDisplayPreferences.defaultRatingSource
  }
  private var capabilityPlacement: MediaCardChromePlacement {
    MediaCardChromePlacement(rawValue: capabilityPlacementRaw)
      ?? MediaCardDisplayPreferences.defaultCapabilityPlacement
  }
  private var editorialPlacement: MediaCardChromePlacement {
    MediaCardChromePlacement(rawValue: editorialPlacementRaw)
      ?? MediaCardDisplayPreferences.defaultEditorialPlacement
  }
  private var watchedStyle: MediaCardWatchedStyle {
    MediaCardWatchedStyle(rawValue: watchedStyleRaw)
      ?? MediaCardDisplayPreferences.defaultWatchedStyle
  }
  private var progressVisibility: MediaCardProgressVisibility {
    MediaCardProgressVisibility(rawValue: progressVisibilityRaw)
      ?? MediaCardDisplayPreferences.defaultProgressVisibility
  }

  private var aspect: CardAspect { card.isLandscape ? .landscape : .poster }

  private var imageURL: String {
    card.landscapeImageURL ?? card.posterURL
  }

  private var playsOnSelect: Bool { card.primaryAction == .play }

  private var activeRating: Rating? {
    card.displayRating(source: ratingSource)
  }

  private var filteredCapabilityBadges: MediaCapabilityBadges {
    MediaCapabilityBadges(
      is4K: show4K && card.is4K,
      isHD: showHD && card.isHD,
      isHDR: showHDR && card.isHDR,
      is3D: show3D && card.is3D,
      hasClosedCaptions: showCC && card.hasClosedCaptions
    )
  }

  private var capabilityChips: [String] {
    var chips: [String] = []
    let badges = filteredCapabilityBadges
    if badges.is4K { chips.append("4K") }
    else if badges.isHD { chips.append("HD") }
    if badges.isHDR { chips.append("HDR") }
    if badges.is3D { chips.append("3D") }
    if badges.hasClosedCaptions { chips.append("CC") }
    return chips
  }

  private var captionMetaParts: [String] {
    var parts: [String] = []
    // Duration lives on landscape artwork (Apple-style time chip), not in the caption.
    if showYear, let year = card.year {
      parts.append(String(year))
    }
    if showGenre, let genre = card.genreLine, !genre.isEmpty {
      parts.append(genre)
    }
    if showCountry, let country = card.countryLine, !country.isEmpty {
      parts.append(country)
    }
    return parts
  }

  private var captionScores: MediaScores {
    // With the aggregate off there is no source picker — show whatever we have.
    guard RatingFeature.combinedEnabled else { return card.scores }
    return card.displayScores(source: ratingSource)
  }

  private var showsCaptionScores: Bool {
    guard captionScores.hasDisplayableScore else { return false }
    // Labelled scores are the only rating a card has while the aggregate is off —
    // they are not the "Under title" branch of a setting that is no longer shown.
    guard RatingFeature.combinedEnabled else { return true }
    return ratingPlacement == .inCaption
  }

  private var showsPlayChrome: Bool {
    guard playsOnSelect else { return false }
    if forcePlayChrome { return true }
#if os(tvOS)
    return cardFocused
#elseif os(macOS)
    return isHovered
#else
    // Touch: the time chip's play glyph already says "this resumes". A second glyph
    // parked in the middle of every still only covers the picture.
    return false
#endif
  }

  private var dimsWatchedArtwork: Bool {
    card.isWatched && watchedStyle.dimsArtwork
  }

  private var isPointerActive: Bool {
#if os(macOS)
    isHovered
#elseif os(tvOS)
    cardFocused
#else
    true
#endif
  }

  private var showsProgressBarNow: Bool {
      guard card.progress != nil ||  ((Int((card.progress ?? 0 * 100).rounded())) != 1) else { return false }
    switch progressVisibility {
    case .always: return true
    case .onFocusHover: return isPointerActive
    }
  }

  private var showsBookmarkOnArtwork: Bool {
    showBookmarkSymbol && (card.isBookmarked || card.isInWatchlist)
  }

  private var landscapeTimeBadge: LandscapeTimeBadge? {
    guard showDuration, card.isLandscape else { return nil }
    return LandscapeTimeBadge(
      durationSeconds: card.durationSeconds,
      progress: card.progress,
      isWatched: card.isWatched
    )
  }

  /// One caption line for landscape: "S1, E12 + 3 more", "E6 + 2 more", or either half alone.
  private var landscapeEpisodeLine: String? {
    guard card.isLandscape else { return nil }
    let episode = card.overlayLabel.flatMap { $0.isEmpty ? nil : $0 }
    let moreCount: Int? = {
      guard let badge = card.badge else { return nil }
      let digits = badge.filter(\.isNumber)
      guard let value = Int(digits), value > 0 else { return nil }
      return value
    }()
    switch (episode, moreCount) {
    case (let episode?, let count?):
      return String(format: String(localized: "%@ + %d more"), episode, count)
    case (let episode?, nil):
      return episode
    case (nil, let count?):
      return String(format: String(localized: "+ %d more"), count)
    case (nil, nil):
      return nil
    }
  }

  public var body: some View {
      VStack(alignment: .center, spacing: Metrics.cardCaptionSpacing) {
      artwork

      if caption != .none {
        captionBlock
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Text(accessibilityTitle))
    .accessibilityValue(Text(accessibilityValue))
    .accessibilityHint(Text(accessibilityHint))
  }

  private var accessibilityHint: String {
    if card.opensCollection { return String(localized: "Opens the collection") }
    return playsOnSelect ? String(localized: "Plays or resumes") : String(localized: "Opens the title")
  }

  private var accessibilityTitle: String {
    if let subtitle = card.subtitle, !subtitle.isEmpty, subtitle != card.title {
      return "\(card.title), \(subtitle)"
    }
    return card.title
  }

  private var accessibilityValue: String {
    var parts: [String] = []
    if let rating = card.rating {
      parts.append("Rating \(rating.formatted)")
    }
    if let progress = card.progress {
      parts.append("\(Int((progress * 1).rounded())) percent watched")
    }
    for stat in card.captionStats {
      parts.append(stat.value)
    }
    if card.is4K { parts.append("4K") }
    if card.isHDR { parts.append("HDR") }
    if card.isWatched { parts.append("Watched") }
    return parts.joined(separator: ", ")
  }

  // MARK: - Artwork

  /// The cell's own width, measured where nothing can clamp it.
  ///
  /// A zero-height `Color.clear` under `maxWidth: .infinity` takes the full width it is
  /// offered whatever the height proposal is, which is the whole point: measuring the
  /// artwork itself made the height it derived feed back into the width it was measured
  /// from, and `aspectRatio(_:contentMode: .fit)` treats *every* width ≤ the offered one
  /// as a valid answer to that. So the card kept whatever width it happened to land on
  /// first — a window resize widened the column and the poster stayed put while the
  /// caption under it grew to the new column, which is the gap that opened between rows.
  private var widthProbe: some View {
    Color.clear
      .frame(maxWidth: .infinity)
      .frame(height: 0)
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { width in
        if width > 0 { artworkWidth = width }
      }
  }

  @ViewBuilder
  private var artwork: some View {
    VStack(spacing: 0) {
      widthProbe
      artworkBox
    }
  }

  @ViewBuilder
  private var artworkBox: some View {
    ZStack {
      stillImage

      if card.isLandscape {
        landscapeOverlays
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if showsProgressBarNow && card.isLandscape && !card.isWatched && ((Int((card.progress ?? 0 * 1).rounded())) != 1), let progress = card.progress {
        progressBar(progress)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      }

      // Top-trailing chips (4K + bookmark). Editorial +N on landscape is a caption label.
      artworkTopTrailing
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

      if !card.isLandscape {
        posterOverlays
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

#if os(macOS)
      // Cheap pointer affordance — dim the still, keep the glass rim on top.
        Color.black.opacity((isHovered && !card.isWatched && dimsWatchedArtwork) ? 0.34 : (isHovered && !dimsWatchedArtwork) ? 0.34 : 0)
        .allowsHitTesting(false)
#endif

      if showsPlayChrome {
        LandscapePlayChromeView(style: playChromeStyle)
          .transition(.opacity.combined(with: .scale(scale: 0.92)))
          .allowsHitTesting(false)
      }
    }
    // Height measured from the card's own width, never negotiated with the caption.
    //
    // This was `.aspectRatio(_:contentMode: .fit)`, which means "fit inside whatever
    // you are offered" — so in a horizontal rail, where the row equalises card heights,
    // a two-line caption ("S1, E1 + 2 more") ate into the artwork and the tile beside a
    // one-line caption came out taller. Continue Watching showed both in the same row.
    // A grid hid the bug because its rows leave height free.
    //
    // Width → height is the only direction that holds in every container.
    .frame(maxWidth: .infinity)
    // Sized correctly on the *first* pass too. Without this the unmeasured frame is
    // `height: nil` — the stack's natural size, which is far larger than the card —
    // and the snap to the measured height rode the subtree's transaction animation,
    // so every card scrolling into view zoomed down from giant. `.fit` gives the right
    // box immediately; the measured frame below then holds it against a caption that
    // would otherwise squeeze it.
    .aspectRatio(aspect.ratio, contentMode: .fit)
    // Pinned in both directions once the probe has reported: `fit` inside exactly
    // `w × w/ratio` is exactly `w × w/ratio`, so the artwork fills its column instead
    // of settling for any narrower box that also satisfies the ratio.
    .frame(width: artworkWidth, height: artworkWidth.map { $0 / aspect.ratio })
    // Never animated: this is a layout fact arriving, not a state change worth showing.
    // `ArtworkImage` sets an animation on its whole subtree for the image fade, and
    // this frame was being carried along by it.
    .animation(nil, value: artworkWidth)
    .opacity(watchedArtworkOpacity)
    .animation(.easeOut(duration: 0.2), value: showsPlayChrome)
#if os(tvOS)
    // One composited lockup so `.borderless` lift/specular stays a single unit —
    // rating/status chips sit inside the hover group rather than as sibling images.
    .hoverEffect(.highlight)
#else
    .clipShape(Self.artworkShape)
    .kinoGlassRim(in: Self.artworkShape)
#if os(macOS)
    .onHover { isHovered = $0 }
    .animation(.easeOut(duration: 0.2), value: isHovered)
    .pointingHandCursorOnHover()
#endif
#endif
  }

  private static var artworkShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
  }

  @ViewBuilder
  private var posterOverlays: some View {
    ZStack(alignment: .topLeading) {
      Color.clear
      if RatingFeature.combinedEnabled, ratingPlacement == .onArtwork, let rating = activeRating {
        RatingBadgeView(rating: rating)
          .padding(3)
          .accessibilityLabel(Text("Rating \(rating.formatted)"))
      }
    }
    .overlay(alignment: .topTrailing) {
      if !card.isLandscape, card.isWatched, watchedStyle.showsCheckmark {
        Image(systemName: "checkmark.circle.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
//#if !os(tvOS)
          // Per-card shadow, rendered on every visible watched glyph in a shelf —
          // measurable tvOS shelf-scroll cost for a barely-visible glow. Off there.
//          .shadow(radius: 4)
//#endif
          .padding(3)
      }
    }
  }

  /// Capability chips + optional bookmark on the artwork (bookmark is rightmost).
  /// Landscape keeps +N out of this corner — it becomes a caption label instead.
  private var artworkTopTrailing: some View {
    HStack(alignment: .top, spacing: 6) {
      if !card.isLandscape, editorialPlacement == .onArtwork, let badge = card.badge {
        editorialBadge(badge)
      }
      if capabilityPlacement == .onArtwork, !capabilityChips.isEmpty {
        capabilityBadgesRow
      }
      if showsBookmarkOnArtwork {
        Image(systemName: "bookmark.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white)
//#if !os(tvOS)
//          .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
//#endif
          .accessibilityLabel(Text("Bookmarked"))
      }
    }
    .padding(6)
  }

  private var capabilityBadgesRow: some View {
    HStack(spacing: 6) {
      ForEach(capabilityChips, id: \.self) { chip in
        Text(chip)
          .font(MediaCapabilityBadgesView.font)
          .foregroundStyle(.white)
          .padding(.horizontal, MediaCapabilityBadgesView.horizontalPadding)
          .padding(.vertical, MediaCapabilityBadgesView.verticalPadding)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
          .accessibilityLabel(Text(chip))
      }
    }
  }

  private func editorialBadge(_ badge: String) -> some View {
    Text(badge)
      .font(.caption.weight(.bold))
      .padding(.horizontal, 4)
      .padding(.vertical, 3)
      .background(Color.KinoPub.accent, in: Capsule())
      .foregroundStyle(.black)
//#if !os(tvOS)
//      .shadow(radius: 4)
//#endif
  }

  private var stillImage: some View {
    // Clear + overlay is the reliable fill: the loader's ideal size otherwise
    // letterboxes inside the 16:9 lockup.
    Color.clear
      .overlay {
        CachedRemoteImage(
          url: URL(string: imageURL),
          contentMode: .fill,
          placeholder: { Color.KinoPub.placeholder },
          failure: { Color.KinoPub.placeholder }
        )
      }
      .clipped()
  }

  /// Progress along the bottom + time chip pinned bottom-leading (never centered).
  @ViewBuilder
  private var landscapeOverlays: some View {
    ZStack(alignment: .bottomLeading) {
      if showsProgressBarNow && card.isLandscape && !card.isWatched && ((Int((card.progress ?? 0 * 1).rounded())) != 1), let progress = card.progress {
        progressBar(progress)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottomLeading) {
      if let landscapeTimeBadge {
        landscapeTimeBadge
          .padding(6)
      }
    }
  }

  private func progressBar(_ progress: Double) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
          Capsule().fill(Color.gray.opacity(0.5))
        Capsule()
              .fill(Color.KinoPub.subtitle)
          .frame(width: geometry.size.width * min(max(progress, 0), 1))
          .frame(height: 3)
      }
    }
    .frame(height: 3)
    .padding(.horizontal, 1)
  }

  // MARK: - Caption

  /// Hidden rather than absent while unfocused, so neighbouring cards keep their
  /// baselines and the row does not jump as focus travels along it.
  private var captionBlock: some View {
    VStack(alignment: .center, spacing: 4) {
      titleRow

      // History's "when did I watch this" line. Shown on landscape cards too, which
      // the original-title rule below deliberately excludes — a history row without a
      // date is the one thing this caption exists to say.
      if let watchedAt = card.watchedAt {
        Text(watchedAt.formatted(date: .abbreviated, time: .shortened))
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .center)
      }

      // Original title is poster-only — landscape captions stay a single title line.
      // Collection covers reuse `subtitle` for the updated date; always show it
      // (independent of the "Original title" appearance toggle).
      if !card.isLandscape,
         (showOriginalTitle || card.opensCollection),
         let subtitle = card.subtitle,
         !subtitle.isEmpty,
         subtitle != card.title {
        Text(subtitle)
          .font(TypeScale.cardSubtitle)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, alignment: .center)
      }

      if card.isLandscape, let line = landscapeEpisodeLine {
        Text(line)
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, alignment: .center)
      }

      if showsCaptionScores {
        MediaScoresView(captionScores)
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
      }

      if !card.captionStats.isEmpty {
        HStack(spacing: 10) {
          ForEach(Array(card.captionStats.enumerated()), id: \.offset) { _, stat in
            HStack(spacing: 4) {
              Image(systemName: stat.systemImage)
              Text(stat.value)
                .monospacedDigit()
            }
          }
        }
        .font(TypeScale.cardMeta)
        .foregroundStyle(Color.KinoPub.subtitle)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
      }

      if !captionMetaParts.isEmpty {
        Text(captionMetaParts.joined(separator: " · "))
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity, alignment: .center)
      }

      captionFiller
    }
    .frame(maxWidth: .infinity, alignment: .center)
    // Never compressed. The artwork's height is pinned to its width now, so a row that
    // equalises card heights has only the caption left to squeeze — which is what cut
    // the second line off. Ideal height, always.
    .fixedSize(horizontal: false, vertical: true)
    .opacity(caption == .always || cardFocused ? 1 : 0)
    .animation(.easeOut(duration: 0.12), value: cardFocused)
  }

  /// Blank lines padding the caption out to a constant number, so every card in a row
  /// is exactly as tall as every other one.
  ///
  /// Reserved in *lines*, not points: a fixed height in points is what
  /// `TVUIKitPosterMetrics.captionHeight` does on tvOS, and it only holds there because
  /// that surface has one type size. Here the same caption is drawn at every Dynamic
  /// Type setting, so the reserve has to be expressed in the thing that actually scales.
  @ViewBuilder
  private var captionFiller: some View {
    let missing = Self.reservedCaptionLines(for: card) - captionLineCount
    if missing > 0 {
      ForEach(0..<missing, id: \.self) { _ in
        Text(verbatim: " ")
          .font(TypeScale.cardMeta)
          .lineLimit(1)
          .accessibilityHidden(true)
      }
    }
  }

  /// How many lines this card's caption actually draws.
  private var captionLineCount: Int {
    var lines = 1 // title
    if card.watchedAt != nil { lines += 1 }
    if !card.isLandscape,
       showOriginalTitle || card.opensCollection,
       let subtitle = card.subtitle, !subtitle.isEmpty, subtitle != card.title {
      lines += 1
    }
    if card.isLandscape, landscapeEpisodeLine != nil { lines += 1 }
    if showsCaptionScores { lines += 1 }
    if !card.captionStats.isEmpty { lines += 1 }
    if !captionMetaParts.isEmpty { lines += 1 }
    return lines
  }

  /// The constant every card of this shape pads up to. Landscape cards carry at most a
  /// title, a watched date and an episode line; posters carry a title plus one meta row
  /// — reserving the worst case for posters too would leave a visible hole under most
  /// of the catalogue, which is why the two shapes differ.
  private static func reservedCaptionLines(for card: MediaCard) -> Int {
    card.isLandscape ? 3 : 2
  }

  /// Title + optional caption chips hug as one group, then the group is centered.
  private var titleRow: some View {
    HStack(spacing: 0) {
      Spacer(minLength: 0)
      HStack(spacing: 6) {
        MarqueeText(
          card.title,
          font: TypeScale.cardTitle,
          alignment: .center,
          fillsWidth: true,
          style: .title
        )
        .frame(minWidth: 0)

        if !card.isLandscape, editorialPlacement == .inCaption, let badge = card.badge {
          editorialBadge(badge)
            .fixedSize()
        }

        if capabilityPlacement == .inCaption, !capabilityChips.isEmpty {
          capabilityBadgesRow
            .fixedSize()
        }
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - Legacy metrics (call sites / placeholders until fully migrated)

  /// Fallback poster width when a caller still needs a concrete size (placeholders).
  public static var cardWidth: CGFloat {
    ShelfMetrics.posters(width: referenceWidth, typeSize: .large)
      .cardWidth(in: referenceWidth)
  }

  public static var posterHeight: CGFloat { cardWidth / CardAspect.poster.ratio }
  public static var landscapeWidth: CGFloat {
    ShelfMetrics.landscape(width: referenceWidth, typeSize: .large)
      .cardWidth(in: referenceWidth)
  }
  public static var landscapeHeight: CGFloat { landscapeWidth / CardAspect.landscape.ratio }
  public static var cornerRadius: CGFloat { Metrics.cardCornerRadius }
  public static var captionSpacing: CGFloat { Metrics.cardCaptionSpacing }
  public static var titleFont: Font { TypeScale.cardTitle }
  public static var subtitleFont: Font { TypeScale.cardSubtitle }

  private static var referenceWidth: CGFloat {
#if os(tvOS)
    1920
#elseif os(macOS)
    1100
#else
    390
#endif
  }
}

// MARK: - Landscape play chrome

/// Visual treatments for the centered play affordance on play-primary landscape cards.
public enum LandscapePlayChromeStyle: String, CaseIterable, Sendable {
  /// Liquid Glass circle — shipping default.
  case glass
  /// Translucent white plate (hero secondary circle language), no backdrop sampling.
  case translucent
  /// Same glass material, larger hit-looking target.
  case glassLarge
}

/// Decorative play glyph in the middle of a landscape still. Not a Button — the
/// parent card / link owns the action.
public struct LandscapePlayChromeView: View {
  public let style: LandscapePlayChromeStyle

  public init(style: LandscapePlayChromeStyle = .glass) {
    self.style = style
  }

  private var diameter: CGFloat {
    switch style {
    case .glass: return 52
    case .translucent: return 52
    case .glassLarge: return 64
    }
  }

  private var iconSize: CGFloat {
    switch style {
    case .glass, .translucent: return 20
    case .glassLarge: return 24
    }
  }

  public var body: some View {
    Image(systemName: "play.fill")
      .font(.system(size: iconSize, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.leading, 2)
      .frame(width: diameter, height: diameter)
      .modifier(LandscapePlayChromeBackground(style: style))
  }
}

private struct LandscapePlayChromeBackground: ViewModifier {
  let style: LandscapePlayChromeStyle

  func body(content: Content) -> some View {
    switch style {
    case .glass, .glassLarge:
      content.kinoGlass(in: Circle())
    case .translucent:
      content
        .background {
          Circle().fill(Color.white.opacity(0.22))
        }
        .overlay {
          Circle()
            .strokeBorder(Color.white.opacity(0.35), lineWidth: Metrics.hairline)
        }
    }
  }
}

#Preview("Poster with 4K/HDR") {
  MediaCardView(
    card: MediaCard(
      id: 1,
      posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
      title: "Стражи Галактики",
      subtitle: "Guardians of the Galaxy",
      imdbRating: 8.1,
      kinopoiskRating: 8.3,
      progress: 0.4,
//      badge: "+2",
      is4K: true,
      isHDR: true
    ),
    caption: .always
  )
  .frame(width: 260)
  .padding()
//  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Poster watched") {
  MediaCardView(
    card: MediaCard(
      id: 2,
      posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
      title: "Стражи Галактики",
      imdbRating: 7.2,
      kinopoiskRating: 7.0,
      isWatched: true,
      is4K: true
    ),
    caption: .always
  )
  .frame(width: 260)
  .padding()
//  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Landscape episode") {
  MediaCardView(
    card: MediaCard(
      id: 3,
      posterURL: "https://m.staticpop.net/poster/item/big/581.jpg",
      title: "Название эпизода подлиннее обычного",
      progress: 0.55,
      landscapeImageURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
      overlayLabel: "S1, E3",
      isSeries: true,
      isInWatchlist: true,
      durationSeconds: 48 * 60,
      primaryAction: .play
    ),
    caption: .always,
    forcePlayChrome: true
  )
  .frame(width: 360)
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}

#Preview("Landscape time states") {
  HStack(alignment: .top, spacing: 16) {
    MediaCardView(
      card: MediaCard(
        id: 1,
        posterURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
        title: "Unwatched",
        landscapeImageURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
        durationSeconds: 62 * 60,
        primaryAction: .play
      ),
      caption: .always,
      forcePlayChrome: false
    )
    .frame(width: 220)
    MediaCardView(
      card: MediaCard(
        id: 2,
        posterURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
        title: "In progress",
        progress: 0.35,
        landscapeImageURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
        isInWatchlist: true,
        durationSeconds: 2 * 3600,
        primaryAction: .play
      ),
      caption: .always,
      forcePlayChrome: false
    )
    .frame(width: 220)
    MediaCardView(
      card: MediaCard(
        id: 3,
        posterURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
        title: "Watched",
        progress: 1,
        landscapeImageURL: "https://m.staticpop.net/poster/item/wide/581.jpg",
        isWatched: true,
        durationSeconds: 2 * 60,
        primaryAction: .play
      ),
      caption: .always
    )
    .frame(width: 220)
  }
  .padding()
  .background(Color.black)
  .preferredColorScheme(.dark)
}
