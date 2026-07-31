//
//  LocalWatchProgressStore.swift
//  KinoPubAppleClient
//
//  Tracks watch progress locally so "Continue Watching" can surface a title the moment the
//  user has actually started it (> 10s), even before/without the backend recording it.
//

import Foundation
import KinoPubBackend

/// A locally persisted resume point for a media item (or a specific episode of a series).
public struct LocalWatchEntry: Codable, Identifiable {
  public let item: MediaItem
  public var position: Double
  public var duration: Double
  public var season: Int?
  public var episode: Int?
  public var updatedAt: Double

  public var id: Int { item.id }

  /// Watch classification for this resume point — the single source of truth (fraction / finished).
  public var watch: WatchProgress { WatchProgress(position: position, duration: duration) }
  public var progress: Double? { watch.fraction }
  public var finished: Bool { watch.isFinished }
}

protocol LocalWatchProgressProvider {
  var localProgressStore: LocalWatchProgressStore { get }
}

/// Thread-safe, file-backed store of local resume points.
final class LocalWatchProgressStore {

  /// Minimum playback before an item is considered "started" and worth resuming — the shared
  /// `WatchProgress` floor, so the local store and the classifier never disagree.
  static let minimumSeconds: Double = WatchProgress.startedSeconds

  private let fileURL: URL
  private let lock = NSLock()
  /// In-memory snapshots of items the user has opened this session (so episode playback,
  /// whose `PlayableItem` is an `Episode`, can still resolve the parent series artwork).
  private var snapshots: [Int: MediaItem] = [:]
  private var entries: [Int: LocalWatchEntry] = [:]

  init() {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    fileURL = directory.appendingPathComponent("local_watch_progress.json")
    load()
  }

  /// Remember the artwork/title for an item the user is browsing (cheap, in-memory only).
  func cacheItem(_ item: MediaItem) {
    lock.lock(); defer { lock.unlock() }
    snapshots[item.id] = item
  }

  /// Record a resume point. No-op for live/trailers (non-finite duration) or before the
  /// minimum threshold, or when we have no snapshot to render a card with.
  func recordProgress(mediaId: Int, position: Double, duration: Double, season: Int?, episode: Int?) {
    guard position >= Self.minimumSeconds, duration.isFinite, duration > 0, position < duration else { return }
    lock.lock(); defer { lock.unlock() }
    guard let snapshot = snapshots[mediaId] ?? entries[mediaId]?.item else { return }
    entries[mediaId] = LocalWatchEntry(item: snapshot,
                                       position: position,
                                       duration: duration,
                                       season: season,
                                       episode: episode,
                                       updatedAt: Date().timeIntervalSince1970)
    persist()
  }

  /// The resume entry for an item, if any (and past the minimum threshold).
  /// A movie (`season == nil`) matches by id alone — there's a single resume point per movie, and
  /// keying it by `episode` (derived from a flaky `videos.first.number`) doesn't round-trip reliably.
  /// A series episode requires an exact `(season, episode)` match.
  func entry(forId id: Int, season: Int?, episode: Int?) -> LocalWatchEntry? {
    lock.lock(); defer { lock.unlock() }
    guard let entry = entries[id], entry.position >= Self.minimumSeconds else { return nil }
    if season == nil {
      return entry.season == nil ? entry : nil
    }
    return (entry.season == season && entry.episode == episode) ? entry : nil
  }

  /// Most-recently-watched first.
  func allEntries() -> [LocalWatchEntry] {
    lock.lock(); defer { lock.unlock() }
    return entries.values
      .filter { $0.position >= Self.minimumSeconds }
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  func clear(id: Int) {
    lock.lock(); defer { lock.unlock() }
    entries[id] = nil
    persist()
  }

  // MARK: - Persistence

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let decoded = try? JSONDecoder().decode([LocalWatchEntry].self, from: data) else { return }
    entries = Dictionary(decoded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }

  /// Must be called with `lock` held.
  private func persist() {
    guard let data = try? JSONEncoder().encode(Array(entries.values)) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
