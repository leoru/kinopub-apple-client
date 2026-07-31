//
//  MediaItemModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import KinoPubKit
import KinoPubMetadata

@MainActor
class MediaItemModel: ObservableObject {

  private var itemsService: VideoContentService
  private var downloadManager: DownloadManager<DownloadMeta>
  private var errorHandler: ErrorHandler
  private var metadataService: MetadataService
  public var linkProvider: NavigationLinkProvider
  public var mediaItemId: Int
  
  @Published public var mediaItem: MediaItem = MediaItem.mock()
  @Published public var itemLoaded: Bool = false
  /// True after `fetchDetails` fails — the page shows `LoadFailedView` instead of a stuck spinner.
  @Published public var loadFailed: Bool = false

  /// "More like this", loaded alongside the page. Empty until it arrives, and left
  /// empty when it fails — the section hides itself rather than erroring over the art.
  @Published public var similarItems: [MediaItem] = []

  /// All bookmark folders, and the ids of those already holding this item.
  @Published public var folders: [Bookmark] = []
  @Published public var folderIDsContainingItem: Set<Int> = []
  @Published public var isWatched: Bool = false

  /// TMDB (and later other sources) overlay. Empty when the proxy is unset or the
  /// title has no IMDb id — the page then draws exactly as before.
  @Published public var externalMetadata: TitleMetadata = TitleMetadata()

  /// Season number → episode schedules from TMDB. Loaded on demand per season.
  @Published public var seasonSchedules: [Int: [EpisodeSchedule]] = [:]

  private var actionsService: UserActionsService
  private var contentStore: ContentStore
  private var identity: MediaIdentity?

  public var isBookmarked: Bool { !folderIDsContainingItem.isEmpty }

  /// - Parameter knownItem: the listing's copy of the item, where the caller has one.
  ///   Only the artwork is used from it — the page waits for the full details before
  ///   drawing anything else, so a stale title or missing seasons can't leak through.
  init(mediaItemId: Int,
       knownItem: MediaItem? = nil,
       itemsService: VideoContentService,
       downloadManager: DownloadManager<DownloadMeta>,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService,
       metadataService: MetadataService = AppContext.shared.metadataService,
       contentStore: ContentStore = AppContext.shared.contentStore) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
    self.downloadManager = downloadManager
    self.actionsService = actionsService
    self.metadataService = metadataService
    self.contentStore = contentStore
    if let knownItem {
      self.mediaItem = knownItem
    }
  }

  func fetchData() {
    loadFailed = false
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = mediaItem.id
        mediaItem.seasons = mediaItem.seasons?.map({ $0.mediaId = mediaId; return $0 })
        isWatched = mediaItem.playbackAction == .playAgain
        itemLoaded = true
        identity = MediaIdentity(mediaItem: mediaItem)
        await loadExternalMetadata()
        if let firstSeason = mediaItem.seasons?.first?.number {
          await ensureSeasonSchedule(firstSeason)
        }
      } catch {
        Logger.app.error("Failed to load item \(self.mediaItemId): \(error)")
        loadFailed = true
      }
    }
    Task {
      await loadBookmarkState()
    }
    Task {
      await loadSimilar()
    }
  }

  func ensureSeasonSchedule(_ seasonNumber: Int) async {
    guard seasonSchedules[seasonNumber] == nil,
          let identity,
          identity.imdb != nil else {
      Logger.metadata.debug(
        "TMDB schedule skip s\(seasonNumber): alreadyLoaded=\(self.seasonSchedules[seasonNumber] != nil) imdb=\(self.identity?.imdb ?? "nil")"
      )
      return
    }
    let kinoCount = mediaItem.seasons?
      .first(where: { $0.number == seasonNumber })?
      .episodes.count ?? 0
    Logger.metadata.info(
      "TMDB schedule fetch kinopub=\(self.mediaItemId) imdb=\(identity.imdb ?? "?") season=\(seasonNumber) kinoEpisodes=\(kinoCount)"
    )
    let episodes = await metadataService.schedule(for: identity, season: seasonNumber)
    seasonSchedules[seasonNumber] = episodes
    let tmdbNums = episodes.map(\.episodeNumber).sorted()
    let kinoNums = Set(
      mediaItem.seasons?
        .first(where: { $0.number == seasonNumber })?
        .episodes.map(\.number) ?? []
    )
    let missingOnKino = tmdbNums.filter { !kinoNums.contains($0) }
    let upcoming = episodes.filter(\.isUpcoming).map(\.episodeNumber)
    Logger.metadata.info(
      "TMDB schedule result season=\(seasonNumber) tmdb=\(episodes.count) [\(tmdbNums.map(String.init).joined(separator: ","))] missingOnKino=\(missingOnKino) upcoming=\(upcoming) sampleStill=\(episodes.first?.still?.absoluteString ?? "nil")"
    )
  }

  func schedule(for episode: Episode, in season: Season) -> EpisodeSchedule? {
    seasonSchedules[season.number]?.first(where: { $0.episodeNumber == episode.number })
  }

  private func loadExternalMetadata() async {
    guard let identity else {
      Logger.metadata.info("TMDB skip kinopub=\(self.mediaItemId): no identity")
      return
    }
    guard let imdb = identity.imdb else {
      Logger.metadata.info("TMDB skip kinopub=\(self.mediaItemId): no imdb id")
      return
    }
    Logger.metadata.info(
      "TMDB metadata fetch kinopub=\(self.mediaItemId) imdb=\(imdb) series=\(identity.isSeries) title=\(identity.title)"
    )
    let meta = await metadataService.metadata(for: identity)
    externalMetadata = meta
    Logger.metadata.info(
      "TMDB metadata result kinopub=\(self.mediaItemId) tmdbId=\(meta.tmdbId.map(String.init) ?? "nil") cast=\(meta.cast.count) photos=\(meta.cast.filter { $0.photo != nil }.count) logo=\(meta.titleLogoURL?.absoluteString ?? "nil") next=\(meta.nextEpisode.map { "S\($0.seasonNumber)E\($0.episodeNumber)" } ?? "nil") status=\(meta.status ?? "nil")"
    )
  }

  // MARK: - Actions

  /// Bookmark state is secondary to the page, so a failure here is logged rather
  /// than thrown at the user over the artwork.
  private func loadBookmarkState() async {
    do {
      async let allFolders = itemsService.fetchBookmarks().items
      async let itemFolders = itemsService.fetchItemFolders(itemId: mediaItemId).items
      folders = try await allFolders
      folderIDsContainingItem = Set(try await itemFolders.map(\.id))
    } catch {
      Logger.app.error("Failed to load bookmark state for \(self.mediaItemId): \(error)")
    }
  }

  /// Related items are a tail-end extra, so — like the bookmark state — a failure is
  /// logged and swallowed rather than thrown at the user over the artwork.
  private func loadSimilar() async {
    do {
      similarItems = try await itemsService.fetchSimilar(for: "\(mediaItemId)").items
    } catch {
      Logger.app.error("Failed to load similar items for \(self.mediaItemId): \(error)")
    }
  }

  func toggleWatched() {
    if let (season, episode) = mediaItem.primaryEpisode {
      toggleWatched(episode: episode, season: season)
      return
    }
    let previous = isWatched
    isWatched.toggle()
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: 1, season: nil)
        contentStore.invalidate(family: .watch)
      } catch {
        isWatched = previous
        errorHandler.setError(error)
      }
    }
  }

  /// Marks one episode watched/unwatched from the season rail's context menu.
  func toggleWatched(episode: Episode, season: Season) {
    let previous = episode.watched
    episode.watched = previous > 0 ? 0 : 1
    // Force the published item to refresh so the rail redraws checkmarks/progress.
    mediaItem = mediaItem
    isWatched = mediaItem.playbackAction == .playAgain
    Task {
      do {
        let watched = try await actionsService.toggleWatching(id: mediaItemId,
                                                              video: episode.number,
                                                              season: season.number)
        if let watched {
          episode.watched = watched
          mediaItem = mediaItem
          isWatched = mediaItem.playbackAction == .playAgain
        }
        contentStore.invalidate(family: .watch)
      } catch {
        episode.watched = previous
        mediaItem = mediaItem
        isWatched = mediaItem.playbackAction == .playAgain
        errorHandler.setError(error)
      }
    }
  }

  /// Drops the title from history so it stops cluttering Continue Watching.
  func clearFromContinueWatching() {
    Task {
      do {
        try await actionsService.clearHistoryForItem(id: mediaItemId)
        contentStore.invalidate(family: .watch)
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  /// Drops one episode from history so it stops cluttering Continue Watching.
  func hide(episode: Episode, season: Season) {
    Task {
      do {
        try await actionsService.clearHistoryForMedia(id: episode.id)
        contentStore.invalidate(family: .watch)
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  /// Bookmark folders live in `ContentStore` too (`.folder(id)`), so a toggle here
  /// needs both folders it affects to refetch next time Library is shown, not sit
  /// stale for up to 10 minutes.
  func toggleFolder(_ folder: Bookmark) {
    let previous = folderIDsContainingItem
    if folderIDsContainingItem.contains(folder.id) {
      folderIDsContainingItem.remove(folder.id)
    } else {
      folderIDsContainingItem.insert(folder.id)
    }
    Task {
      do {
        try await itemsService.toggleBookmark(itemId: mediaItemId, folderId: folder.id)
        contentStore.invalidate(family: .bookmarks)
      } catch {
        folderIDsContainingItem = previous
        errorHandler.setError(error)
      }
    }
  }
  
  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    let meta = DownloadMeta.make(from: item, quality: file.quality)
#if os(iOS)
    // Prefer offline HLS (.movpkg) — full quality + all dubs/subs. Fall back to mp4.
    if let hls = URL(string: file.url.hls4), !file.url.hls4.isEmpty {
      let result = AppContext.shared.hlsDownloadManager.startDownload(meta: meta, hlsURL: hls)
      switch result {
      case .started, .alreadyDownloading, .alreadyDownloaded:
        return
      case .failed:
        break
      }
    }
#endif
    guard let url = URL(string: file.url.http), !file.url.http.isEmpty else { return }
    _ = downloadManager.startDownload(url: url, withMetadata: meta)
  }

  /// Enqueues every episode of a season at `quality` (mp4 path). Non-TV only.
  @discardableResult
  func startSeasonDownload(mediaId: Int, seriesTitle: String, season: Season, quality: String?) -> Int {
#if os(tvOS)
    return 0
#else
    AppContext.shared.seasonDownloadManager.downloadSeason(
      mediaId: mediaId,
      seriesTitle: seriesTitle,
      season: season,
      quality: quality
    )
#endif
  }

}

extension MediaIdentity {
  init(mediaItem: MediaItem) {
    self.init(
      kinopubId: mediaItem.id,
      imdb: mediaItem.imdb.map(TMDBIDFormatter.imdbString(from:)),
      kinopoisk: mediaItem.kinopoisk,
      title: mediaItem.localizedTitle,
      originalTitle: mediaItem.originalTitle,
      year: mediaItem.year,
      isSeries: mediaItem.isSeries
    )
  }
}
