//
//  SeasonDownloadManager.swift
//  KinoPubAppleClient
//
//  Downloads an entire season in one action by enqueuing each episode through the shared
//  DownloadManager. Tracks per-season group progress and posts a single "season downloaded"
//  notification when the last episode of a group finishes.
//

import Foundation
import KinoPubBackend
import KinoPubKit
import OSLog
import KinoPubLogging

final class SeasonDownloadManager: ObservableObject {

  /// In-progress (or just-finished) bulk season download.
  struct Group: Identifiable {
    let id: String
    let seriesTitle: String
    let seasonNumber: Int
    let total: Int
    var completed: Int
    var pendingURLs: Set<URL>

    var progress: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    var isComplete: Bool { completed >= total }
  }

  @Published private(set) var groups: [String: Group] = [:]

  private let downloadManager: DownloadManager<DownloadMeta>
  private let notifications: DownloadNotificationManager

  init(downloadManager: DownloadManager<DownloadMeta>, notifications: DownloadNotificationManager) {
    self.downloadManager = downloadManager
    self.notifications = notifications
  }

  /// Distinct quality labels available across a season's episodes, best (highest resolution) first.
  static func availableQualities(in season: Season) -> [String] {
    var seen = Set<String>()
    var result: [(label: String, resolution: Int)] = []
    for episode in season.episodes {
      for file in episode.files where !seen.contains(file.quality) {
        seen.insert(file.quality)
        result.append((file.quality, file.resolution))
      }
    }
    return result.sorted { $0.resolution > $1.resolution }.map { $0.label }
  }

  /// Enqueues every episode of `season` at `quality` (falls back to the best available file per
  /// episode). Episodes already downloading are skipped. Returns the number of episodes queued.
  @discardableResult
  func downloadSeason(mediaId: Int,
                      seriesTitle: String,
                      season: Season,
                      quality: String?) -> Int {
    var queued = Set<URL>()
    for episode in season.episodes {
      guard let file = pickFile(from: episode.files, quality: quality),
            let url = URL(string: file.url.http) else { continue }
      if downloadManager.activeDownloads[url] != nil { continue }
      let meta = downloadMeta(mediaId: mediaId, season: season, episode: episode, quality: file.quality)
      _ = downloadManager.startDownload(url: url, withMetadata: meta)
      queued.insert(url)
    }
    guard !queued.isEmpty else { return 0 }
    let id = groupID(mediaId: mediaId, seasonNumber: season.number)
    groups[id] = Group(id: id,
                       seriesTitle: seriesTitle,
                       seasonNumber: season.number,
                       total: queued.count,
                       completed: 0,
                       pendingURLs: queued)
    Logger.app.info("[SEASON DL] Queued \(queued.count) episodes for \(id)")
    return queued.count
  }

  /// Advances the season group a finished download belongs to. Returns `true` when the URL was part
  /// of a group, so the caller can suppress the per-episode "download complete" notification.
  @discardableResult
  func handleFinished(url: URL) -> Bool {
    guard let key = groups.first(where: { $0.value.pendingURLs.contains(url) })?.key else { return false }
    groups[key]?.pendingURLs.remove(url)
    groups[key]?.completed += 1
    if let group = groups[key], group.isComplete {
      notifications.notifySeasonFinished(
        title: "\(group.seriesTitle) — \(seasonLabel(group.seasonNumber))",
        identifier: group.id)
      Logger.app.info("[SEASON DL] Completed group \(group.id)")
    }
    return true
  }

  // MARK: - Helpers

  private func groupID(mediaId: Int, seasonNumber: Int) -> String {
    "season_\(mediaId)_\(seasonNumber)"
  }

  private func seasonLabel(_ number: Int) -> String {
    "\(NSLocalizedString("Season", comment: "")) \(number)"
  }

  /// Picks the file matching `quality`; otherwise the highest-resolution file available.
  private func pickFile(from files: [FileInfo], quality: String?) -> FileInfo? {
    if let quality, let exact = files.first(where: { $0.quality == quality }) { return exact }
    return files.max(by: { $0.resolution < $1.resolution })
  }

  /// Mirrors `SeasonModel.downloadMeta` but also records quality + episode marker so the Downloads
  /// list can show "S1E3 · 1080p".
  private func downloadMeta(mediaId: Int, season: Season, episode: Episode, quality: String) -> DownloadMeta {
    let name = "S\(season.number)E\(episode.number)"
    return DownloadMeta(id: episode.id,
                        files: episode.files,
                        originalTitle: name,
                        localizedTitle: episode.fixedTitle,
                        imageUrl: episode.thumbnail,
                        metadata: WatchingMetadata(id: mediaId, video: episode.number, season: season.number),
                        quality: quality,
                        episode: name)
  }
}
