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
import KinoPubUI

/// The viewer's own kino.pub thumbs vote for a title. Votes are one-shot server-side.
enum MediaItemUserVote: Equatable {
  case none
  case up
  case down
}

/// Remembers a cast vote across launches so the thumbs stay highlighted on revisit.
private enum UserVoteMemory {
  private static let key = "mediaItemUserVotes"

  static func vote(for id: Int) -> MediaItemUserVote {
    guard let raw = UserDefaults.standard.dictionary(forKey: key)?["\(id)"] as? String else {
      return .none
    }
    switch raw {
    case "up": return .up
    case "down": return .down
    default: return .none
    }
  }

  static func set(id: Int, vote: MediaItemUserVote) {
    var map = UserDefaults.standard.dictionary(forKey: key) ?? [:]
    switch vote {
    case .none: map.removeValue(forKey: "\(id)")
    case .up: map["\(id)"] = "up"
    case .down: map["\(id)"] = "down"
    }
    UserDefaults.standard.set(map, forKey: key)
  }
}

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
  /// True after `fetchDetails` fails — the page shows `UnavailableView` instead of a stuck spinner.
  @Published public var loadFailed: Bool = false
  /// The failure behind `loadFailed`, so the retry state can say what actually went wrong.
  @Published public var loadError: Error?

  /// "More like this", loaded alongside the page. Empty until it arrives, and left
  /// empty when it fails — the section hides itself rather than erroring over the art.
  @Published public var similarItems: [MediaItem] = []

  /// All bookmark folders, and the ids of those already holding this item.
  @Published public var folders: [Bookmark] = []
  @Published public var folderIDsContainingItem: Set<Int> = []
  @Published public var isWatched: Bool = false
  @Published public var myVote: MediaItemUserVote = .none
  @Published public var likeCount: Int = 0
  @Published public var dislikeCount: Int = 0
  /// Glyph + Title confirmation for hero library actions. Cleared by the view
  /// modifier as soon as presentation starts.
  @Published public var hudToast: HudToast?

  /// TMDB (and later other sources) overlay. Empty when the proxy is unset or the
  /// title has no IMDb id — the page then draws exactly as before.
  @Published public var externalMetadata: TitleMetadata = TitleMetadata()

  /// True once `loadExternalMetadata` finishes or is skipped. Cast photos wait on
  /// this before falling back to the pushbr CDN so URLs don't swap mid-paint.
  @Published public var externalMetadataLoaded: Bool = false

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
      AppContext.shared.localProgressStore.cacheItem(knownItem)
    }
  }

  func fetchData() {
    loadFailed = false
    loadError = nil
    externalMetadataLoaded = false
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = mediaItem.id
        mediaItem.seasons = mediaItem.seasons?.map({ $0.mediaId = mediaId; return $0 })
        AppContext.shared.localProgressStore.cacheItem(mediaItem)
        isWatched = mediaItem.playbackAction == .playAgain
        // Without this the hero's follow control opened as "not following" on every
        // visit, whatever the account actually had, and the first tap unfollowed.
        isInWatchlist = mediaItem.inWatchlist ?? mediaItem.subscribed ?? false
        seedVoteCounts()
        itemLoaded = true
        identity = MediaIdentity(mediaItem: mediaItem)
        await loadExternalMetadata()
        // The "what's next" data lives on the latest season, not the first one —
        // and a long-running show should not fan out schedule fetches for every
        // published season (the rest load lazily when their tab is selected).
        if let lastSeason = mediaItem.seasons?.last?.number {
          await ensureSeasonSchedule(lastSeason)
        }
      } catch {
        Logger.app.error("Failed to load item \(self.mediaItemId): \(error)")
        loadFailed = true
        loadError = error
        externalMetadataLoaded = true
      }
    }
    Task {
      await loadBookmarkState()
    }
    Task {
      await loadSimilar()
    }
  }

  func ensureSeasonSchedule(_ kinoSeasonNumber: Int) async {
    guard seasonSchedules[kinoSeasonNumber] == nil,
          let identity,
          identity.imdb != nil else {
      Logger.metadata.debug(
        "TMDB schedule skip s\(kinoSeasonNumber): alreadyLoaded=\(self.seasonSchedules[kinoSeasonNumber] != nil) imdb=\(self.identity?.imdb ?? "nil")"
      )
      return
    }

    guard let tmdbSeason = tmdbSeasonNumber(forKinoSeason: kinoSeasonNumber) else {
      // No sensible TMDB counterpart (renumbered/special block) — mark loaded so we
      // don't refetch on every tab visit, and simply show kino.pub episodes alone.
      Logger.metadata.info(
        "TMDB schedule skip s\(kinoSeasonNumber): no TMDB match (title=\(self.kinoSeason(for: kinoSeasonNumber)?.title ?? "nil"))"
      )
      seasonSchedules[kinoSeasonNumber] = []
      return
    }

    let kinoCount = kinoSeason(for: kinoSeasonNumber)?.episodes.count ?? 0
    Logger.metadata.info(
      "TMDB schedule fetch kinopub=\(self.mediaItemId) imdb=\(identity.imdb ?? "?") season=\(kinoSeasonNumber)→tmdb=\(tmdbSeason) kinoEpisodes=\(kinoCount)"
    )
    let episodes = await metadataService.schedule(for: identity, season: tmdbSeason)
    seasonSchedules[kinoSeasonNumber] = episodes
    let tmdbNums = episodes.map(\.episodeNumber).sorted()
    let kinoNums = Set(kinoSeason(for: kinoSeasonNumber)?.episodes.map(\.number) ?? [])
    let missingOnKino = tmdbNums.filter { !kinoNums.contains($0) }
    let upcoming = episodes.filter(\.isUpcoming).map(\.episodeNumber)
    Logger.metadata.info(
      "TMDB schedule result season=\(kinoSeasonNumber) tmdb=\(episodes.count) [\(tmdbNums.map(String.init).joined(separator: ","))] missingOnKino=\(missingOnKino) upcoming=\(upcoming) sampleStill=\(episodes.first?.still?.absoluteString ?? "nil")"
    )
  }

  private func kinoSeason(for number: Int) -> Season? {
    mediaItem.seasons?.first(where: { $0.number == number })
  }

  /// kino.pub sometimes re-numbers its season blocks from 1 while titling them
  /// "Сезон N" — TMDB numbers by the real season. Map by the title's digits first
  /// (validated against TMDB's season list), then by kino number, else give up:
  /// asking TMDB for "season 1" of a block that is really season 14 produced
  /// decade-old "missing episodes" on a current show.
  private func tmdbSeasonNumber(forKinoSeason kinoNumber: Int) -> Int? {
    guard let kinoSeason = kinoSeason(for: kinoNumber) else { return nil }
    let tmdbNumbers = Set(externalMetadata.seasonSummaries.map(\.seasonNumber))
    if let titleNumber = kinoSeason.titleSeasonNumber,
       tmdbNumbers.contains(titleNumber) {
      return titleNumber
    }
    if tmdbNumbers.isEmpty || tmdbNumbers.contains(kinoNumber) {
      return kinoNumber
    }
    return nil
  }

  func schedule(for episode: Episode, in season: Season) -> EpisodeSchedule? {
    seasonSchedules[season.number]?.first(where: { $0.episodeNumber == episode.number })
  }

  private func loadExternalMetadata() async {
    defer { externalMetadataLoaded = true }
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
  /// than thrown at the user over the artwork. Membership comes from the item
  /// payload + local store — never `get-item-folders`.
  private func loadBookmarkState() async {
    if let bookmarks = mediaItem.bookmarks {
      let ids = Set(bookmarks.map(\.id))
      folderIDsContainingItem = ids
      BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: ids)
    } else {
      folderIDsContainingItem = BookmarkMembershipStore.shared.folderIDs(for: mediaItemId)
    }
    do {
      folders = try await itemsService.fetchBookmarks().items
    } catch {
      Logger.app.error("Failed to load bookmark folders for \(self.mediaItemId): \(error)")
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
    presentWatchedHud(nowWatched: isWatched)
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
    presentWatchedHud(nowWatched: episode.watched > 0)
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

  /// Marks a whole season watched/unwatched at once. `/v1/watching/toggle` with a
  /// season and no video number is the API's own bulk form, and it flips the season
  /// to the opposite of what it mostly is — so a part-watched season completes rather
  /// than resetting. The response carries no per-episode flags, hence the refetch.
  func toggleWatched(season: Season) {
    let target = season.episodes.contains { !$0.isWatched } ? 1 : 0
    let previous = season.episodes.map(\.watched)
    for episode in season.episodes {
      episode.watched = target
    }
    mediaItem = mediaItem
    isWatched = mediaItem.playbackAction == .playAgain
    presentWatchedHud(nowWatched: target > 0)
    Task {
      do {
        _ = try await actionsService.toggleWatching(id: mediaItemId, video: nil, season: season.number)
        contentStore.invalidate(family: .watch)
        // The optimistic flip above is a guess at what a bulk toggle did; the item's
        // own episode flags are the answer.
        var refreshed = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = refreshed.id
        refreshed.seasons = refreshed.seasons?.map({ $0.mediaId = mediaId; return $0 })
        mediaItem = refreshed
        AppContext.shared.localProgressStore.cacheItem(refreshed)
        isWatched = mediaItem.playbackAction == .playAgain
      } catch {
        for (episode, watched) in zip(season.episodes, previous) {
          episode.watched = watched
        }
        mediaItem = mediaItem
        isWatched = mediaItem.playbackAction == .playAgain
        errorHandler.setError(error)
      }
    }
  }

  /// Drops the title from history so it stops cluttering Continue Watching.
  func clearFromContinueWatching() {
    presentHud(systemImage: "trash", title: "Removed")
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
      presentHud(systemImage: "bookmark", title: "Removed")
    } else {
      folderIDsContainingItem.insert(folder.id)
      presentHud(systemImage: "bookmark.fill", title: "Bookmarked")
    }
    BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: folderIDsContainingItem)
    Task {
      do {
        try await itemsService.toggleBookmark(itemId: mediaItemId, folderId: folder.id)
        contentStore.invalidate(family: .bookmarks)
      } catch {
        folderIDsContainingItem = previous
        BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: previous)
        errorHandler.setError(error)
      }
    }
  }

  /// Series follow state — `/v1/watching/togglewatchlist`, seeded from the item's own
  /// `in_watchlist` / `subscribed` flags. Distinct from bookmark folders (a shelf you
  /// file things on) and from watched (how far you got).
  @Published public var isInWatchlist: Bool = false

  func toggleWatchlist() {
    let previous = isInWatchlist
    isInWatchlist.toggle()
    if isInWatchlist {
      presentHud(systemImage: "plus", title: "Added to Watchlist")
    } else {
      presentHud(systemImage: "minus", title: "Removed from Watchlist")
    }
    Task {
      do {
        try await actionsService.toggleWatchlist(id: mediaItemId)
        contentStore.invalidate(family: .watch)
      } catch {
        isInWatchlist = previous
        errorHandler.setError(error)
      }
    }
  }

  /// Create a bookmark folder and put this item in it.
  func createFolderAndAdd(named name: String) {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }
    Task {
      do {
        let folderId = try await actionsService.createBookmarkFolder(title: title)
        try await itemsService.toggleBookmark(itemId: mediaItemId, folderId: folderId)
        folderIDsContainingItem.insert(folderId)
        BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: folderIDsContainingItem)
        folders = try await itemsService.fetchBookmarks().items
        contentStore.invalidate(family: .bookmarks)
        presentHud(systemImage: "bookmark.fill", title: "Bookmarked")
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  private func presentWatchedHud(nowWatched: Bool) {
    if nowWatched {
      presentHud(systemImage: "checkmark", title: "Watched")
    } else {
      presentHud(systemImage: "eye", title: "Marked as New")
    }
  }

  private func presentHud(systemImage: String, title: String) {
    hudToast = HudToast(systemImage: systemImage, title: title.localized)
  }

  /// kino.pub exposes aggregate as `rating` + `rating_votes` (+ percentage); derive like/dislike
  /// for the initial display. A real vote refreshes them from `VoteData`.
  private func seedVoteCounts() {
    myVote = UserVoteMemory.vote(for: mediaItemId)
    if let votes = mediaItem.communityVotes {
      likeCount = votes.likes
      dislikeCount = votes.dislikes
    } else {
      likeCount = 0
      dislikeCount = 0
    }
  }

  /// Cast a like (`up: true` → `like=1`) or dislike. One-shot — can't switch or re-cast.
  func vote(up: Bool) {
    let target: MediaItemUserVote = up ? .up : .down
    if myVote == target { return }
    if myVote != .none { return }

    myVote = target
    UserVoteMemory.set(id: mediaItemId, vote: target)
    if up { likeCount += 1 } else { dislikeCount += 1 }
    Task {
      do {
        let result = try await actionsService.vote(id: mediaItemId, like: up ? 1 : 0)
        if result.voted {
          if let p = result.positiveCount { likeCount = p }
          if let n = result.negativeCount { dislikeCount = n }
        } else {
          // Already voted on another device — keep highlight, undo optimistic bump.
          if up { likeCount = max(0, likeCount - 1) } else { dislikeCount = max(0, dislikeCount - 1) }
        }
      } catch {
        myVote = .none
        UserVoteMemory.set(id: mediaItemId, vote: .none)
        if up { likeCount = max(0, likeCount - 1) } else { dislikeCount = max(0, dislikeCount - 1) }
        errorHandler.setError(error)
      }
    }
  }
  
  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    guard FeatureFlags.downloadsEnabled else { return }
    let meta = DownloadMeta.make(from: item, quality: file.quality)
#if os(iOS)
    // Prefer offline HLS (.movpkg) — full quality + all dubs/subs. Fall back to mp4.
    if let hls = URL(string: file.url.hls4), !file.url.hls4.isEmpty {
      Task { @MainActor in
        let result = await AppContext.shared.hlsDownloadManager.startDownload(meta: meta, hlsURL: hls)
        switch result {
        case .started, .alreadyDownloading, .alreadyDownloaded:
          return
        case .failed:
          guard let url = URL(string: file.url.http), !file.url.http.isEmpty else { return }
          _ = self.downloadManager.startDownload(url: url, withMetadata: meta)
        }
      }
      return
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
    guard FeatureFlags.downloadsEnabled else { return 0 }
    return AppContext.shared.seasonDownloadManager.downloadSeason(
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
