//
//  MediaLibraryStore.swift
//  KinoPubAppleClient
//
//  Port of dungeon-master-xx's optimistic *item* library — one object the rest of
//  the app can ask about a title without re-querying:
//   • watchlist membership — owned, optimistic, persisted
//   • watched overrides (movie / episode) — win over the server until it agrees
//   • the viewer's own like/dislike (kino.pub votes are one-shot with no read-back)
//   • download status — façade over the existing HLS / mp4 stores
//   • watch progress — delegated to LocalWatchProgressStore
//
//  Not a ContentStore replacement: Home/Library *rows* stay on ContentStore.
//  Not a bookmark replacement: folder membership stays on BookmarkMembershipStore
//  and the folder list on BookmarkFoldersStore (detail pages still never fetch
//  GET /v1/bookmarks). This store is the missing per-item half.
//

import Foundation
import Combine
import KinoPubBackend
import KinoPubKit

/// Not `@MainActor` so it can be built inside `AppContext.shared`'s nonisolated
/// initializer; mutations come from views / `@MainActor` models, and the download
/// republish sinks deliver on main, so `@Published` stays on the main thread.
final class MediaLibraryStore: ObservableObject {

  enum DownloadStatus: Equatable {
    case none
    case downloading(Double)   // 0...1
    case downloaded
  }

  // MARK: - Owned optimistic state (persisted)

  private struct Record: Codable {
    var inWatchlist: Bool?
  }

  @Published private var records: [Int: Record] = [:]
  /// Optimistic "watched" overrides — win over the server's value until a fetch
  /// reconciles them away (so the server can still drive auto-watched / cross-device).
  @Published private var movieWatchedOverride: [Int: Bool] = [:]
  @Published private var episodeWatchedOverride: [Int: Bool] = [:]
  /// The user's like (`true`) / dislike (`false`) per item id.
  @Published private var userVotes: [Int: Bool] = [:]

  /// In-memory index of completed downloads (`id|video|season`) so per-card status
  /// checks are O(1) instead of reading plists on every render.
  private var downloadedKeys: Set<String> = []

  private struct Persisted: Codable {
    var records: [Int: Record] = [:]
    var movieWatched: [Int: Bool] = [:]
    var episodeWatched: [Int: Bool] = [:]
    var userVotes: [Int: Bool]?
  }

  // MARK: - Façade dependencies (not owned)

  private let downloadManager: DownloadManager<DownloadMeta>
  private let hlsDownloadManager: HLSAssetDownloadManager
  private let hlsStore: HLSDownloadsStore
  private let downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  private let progressStore: LocalWatchProgressStore

  private let fileURL: URL
  private var cancellables = Set<AnyCancellable>()

  /// UserDefaults key the detail page used before this store existed.
  private static let legacyVoteDefaultsKey = "mediaItemUserVotes"

  init(downloadManager: DownloadManager<DownloadMeta>,
       hlsDownloadManager: HLSAssetDownloadManager,
       hlsStore: HLSDownloadsStore,
       downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>,
       progressStore: LocalWatchProgressStore) {
    self.downloadManager = downloadManager
    self.hlsDownloadManager = hlsDownloadManager
    self.hlsStore = hlsStore
    self.downloadedFilesDatabase = downloadedFilesDatabase
    self.progressStore = progressStore
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    fileURL = directory.appendingPathComponent("media_library.json")
    load()
    rebuildDownloadedIndex()

    downloadManager.$activeDownloads
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.rebuildDownloadedIndex(); self?.objectWillChange.send() }
      .store(in: &cancellables)
    hlsDownloadManager.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.rebuildDownloadedIndex(); self?.objectWillChange.send() }
      .store(in: &cancellables)
  }

  // MARK: - Watchlist

  /// Optimistic watchlist membership, or nil if unknown (caller falls back to the payload).
  func inWatchlist(itemId: Int) -> Bool? {
    records[itemId]?.inWatchlist
  }

  func setWatchlist(itemId: Int, value: Bool) {
    var record = records[itemId] ?? Record()
    record.inWatchlist = value
    records[itemId] = record
    persist()
  }

  /// Seed from the item payload the first time we see it, without clobbering a
  /// toggle the user already made while this page was loading.
  func seedWatchlistIfAbsent(itemId: Int, value: Bool) {
    if records[itemId]?.inWatchlist != nil { return }
    setWatchlist(itemId: itemId, value: value)
  }

  // MARK: - Watched (optimistic override over the server value)

  func movieWatched(itemId: Int, serverWatched: Bool) -> Bool {
    movieWatchedOverride[itemId] ?? serverWatched
  }

  func episodeWatched(episodeId: Int, serverWatched: Bool) -> Bool {
    episodeWatchedOverride[episodeId] ?? serverWatched
  }

  func setMovieWatched(itemId: Int, value: Bool) {
    movieWatchedOverride[itemId] = value
    persist()
  }

  func setEpisodeWatched(episodeId: Int, value: Bool) {
    episodeWatchedOverride[episodeId] = value
    persist()
  }

  /// Drop overrides that fresh server data now confirms, so the server drives again.
  func reconcileWatched(movieItemId: Int, serverMovieWatched: Bool?, episodes: [(id: Int, watched: Bool)]) {
    var changed = false
    if let server = serverMovieWatched, movieWatchedOverride[movieItemId] == server {
      movieWatchedOverride[movieItemId] = nil
      changed = true
    }
    for episode in episodes where episodeWatchedOverride[episode.id] == episode.watched {
      episodeWatchedOverride[episode.id] = nil
      changed = true
    }
    if changed { persist() }
  }

  // MARK: - Like / dislike

  /// `true` = liked, `false` = disliked, nil = not voted.
  func userVote(itemId: Int) -> Bool? {
    userVotes[itemId]
  }

  func setUserVote(itemId: Int, up: Bool) {
    guard userVotes[itemId] != up else { return }
    userVotes[itemId] = up
    persist()
  }

  func clearUserVote(itemId: Int) {
    guard userVotes[itemId] != nil else { return }
    userVotes[itemId] = nil
    persist()
  }

  // MARK: - Downloads (façade)

  /// DESIGN: poster/card download chrome can read `downloadStatus(itemId:video:season:)` —
  /// do not invent a second card overlay; pair with the existing badge/scrim if it lands.
  func downloadStatus(itemId: Int, video: Int?, season: Int?) -> DownloadStatus {
    if isDownloaded(itemId: itemId, video: video, season: season) { return .downloaded }
    if let progress = activeDownloadProgress(itemId: itemId, video: video, season: season) {
      return .downloading(progress)
    }
    return .none
  }

  func isDownloaded(itemId: Int, video: Int?, season: Int?) -> Bool {
    downloadedKeys.contains(Self.downloadKey(itemId, video, season))
  }

  /// Whether the title has any completed download (any episode/video) — for poster cards.
  func isDownloadedAny(itemId: Int) -> Bool {
    let prefix = "\(itemId)|"
    return downloadedKeys.contains { $0.hasPrefix(prefix) }
  }

  func isDownloadingAny(itemId: Int) -> Bool {
    if hlsDownloadManager.activeDownloads.contains(where: { $0.meta.id == itemId }) { return true }
    return downloadManager.activeDownloads.values.contains(where: { $0.metadata.id == itemId })
  }

  private static func downloadKey(_ id: Int, _ video: Int?, _ season: Int?) -> String {
    "\(id)|\(video.map(String.init) ?? "-")|\(season.map(String.init) ?? "-")"
  }

  private func rebuildDownloadedIndex() {
    var keys = Set<String>()
    for asset in hlsStore.readData() where asset.fileExists {
      keys.insert(Self.downloadKey(asset.meta.id, asset.meta.metadata.video, asset.meta.metadata.season))
    }
    for file in (downloadedFilesDatabase.readData() ?? [])
    where FileManager.default.fileExists(atPath: file.localFileURL.path) {
      keys.insert(Self.downloadKey(file.metadata.id, file.metadata.metadata.video, file.metadata.metadata.season))
    }
    downloadedKeys = keys
  }

  func activeDownloadProgress(itemId: Int, video: Int?, season: Int?) -> Double? {
    if let hls = hlsDownloadManager.activeDownloads.first(where: {
      $0.meta.id == itemId && $0.meta.metadata.video == video && $0.meta.metadata.season == season
    }) {
      return Double(hls.progress)
    }
    if let mp4 = downloadManager.activeDownloads.values.first(where: {
      $0.metadata.id == itemId && $0.metadata.metadata.video == video && $0.metadata.metadata.season == season
    }) {
      return Double(mp4.progress)
    }
    return nil
  }

  // MARK: - Watch progress (delegated)

  func watchProgress(itemId: Int, season: Int?, episode: Int?) -> Double? {
    progressStore.entry(forId: itemId, season: season, episode: episode)?.progress
  }

  // MARK: - Account change

  /// Drops per-account optimistic state. Bookmark stores and ResponseCache are
  /// cleared (or not) by their own owners — genres/countries stay.
  func clear() {
    records = [:]
    movieWatchedOverride = [:]
    episodeWatchedOverride = [:]
    userVotes = [:]
    try? FileManager.default.removeItem(at: fileURL)
    UserDefaults.standard.removeObject(forKey: Self.legacyVoteDefaultsKey)
    objectWillChange.send()
  }

  // MARK: - Persistence

  private func load() {
    if let data = try? Data(contentsOf: fileURL),
       let decoded = try? JSONDecoder().decode(Persisted.self, from: data) {
      records = decoded.records
      movieWatchedOverride = decoded.movieWatched
      episodeWatchedOverride = decoded.episodeWatched
      userVotes = decoded.userVotes ?? [:]
    }
    migrateLegacyVotesIfNeeded()
  }

  /// The detail page used to keep votes in UserDefaults. Fold them in once so a
  /// highlight the viewer already cast isn't lost on the first launch of this store.
  private func migrateLegacyVotesIfNeeded() {
    guard let raw = UserDefaults.standard.dictionary(forKey: Self.legacyVoteDefaultsKey) as? [String: String]
    else { return }
    var changed = false
    for (key, value) in raw {
      guard let id = Int(key), userVotes[id] == nil else { continue }
      switch value {
      case "up": userVotes[id] = true; changed = true
      case "down": userVotes[id] = false; changed = true
      default: break
      }
    }
    if changed { persist() }
  }

  private func persist() {
    let snapshot = Persisted(records: records,
                             movieWatched: movieWatchedOverride,
                             episodeWatched: episodeWatchedOverride,
                             userVotes: userVotes)
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}

protocol MediaLibraryProvider {
  var libraryState: MediaLibraryStore { get }
}
