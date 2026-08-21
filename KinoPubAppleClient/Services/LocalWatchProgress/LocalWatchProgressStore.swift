//
//  LocalWatchProgressStore.swift
//  KinoPubAppleClient
//
//  Tracks watch progress locally so "Continue Watching" can surface a title the moment the
//  user has actually started it (> 10s), even before/without the backend recording it.
//

import Foundation
import KinoPubBackend

extension Notification.Name {
  /// Posted after a local resume point is written or cleared. Home paints from this
  /// without invalidating `ContentStore` — the row's TTL is the server snapshot, not
  /// the playhead.
  static let localWatchProgressDidChange = Notification.Name("KinoPub.localWatchProgressDidChange")
}

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
  public var progress: Double? { watch.resumeFraction }
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

  /// The cached payload for an item, when the user has browsed it this session. An
  /// `Episode` carries no genres or countries, so track selection reads them from here.
  func snapshot(for id: Int) -> MediaItem? {
    lock.lock(); defer { lock.unlock() }
    return snapshots[id]
  }

  /// Record a resume point. No-op for live/trailers (non-finite duration) or before the
  /// minimum threshold, or when we have no snapshot to render a card with.
  ///
  /// `position < duration` keeps the exact end-of-file tick for `recordFinished`.
  /// A position already inside the credits window is still written;
  /// `WatchProgress` classifies it as finished on read, so Continue Watching
  /// does not grow a resume bar from it.
  func recordProgress(mediaId: Int, position: Double, duration: Double, season: Int?, episode: Int?) {
    guard duration.isFinite, duration > 0, position < duration else { return }
    let watch = WatchProgress(position: position, duration: duration)
    guard watch.hasStarted else { return }
    let changed = mutate { snapshots, entries in
      guard let snapshot = snapshots[mediaId] ?? entries[mediaId]?.item else { return false }
      entries[mediaId] = LocalWatchEntry(item: snapshot,
                                         position: position,
                                         duration: duration,
                                         season: season,
                                         episode: episode,
                                         updatedAt: Date().timeIntervalSince1970)
      return true
    }
    if changed { notify() }
  }

  /// End of playback: keep a finished tombstone so Continue Watching can hide a film
  /// or step a series to the next episode without waiting out Home's TTL, and without
  /// `ContentStore.invalidate(.watch)`.
  func recordFinished(mediaId: Int, duration: Double, season: Int?, episode: Int?) {
    guard duration.isFinite, duration > 0 else { return }
    let changed = mutate { snapshots, entries in
      guard let snapshot = snapshots[mediaId] ?? entries[mediaId]?.item else { return false }
      entries[mediaId] = LocalWatchEntry(item: snapshot,
                                         position: duration,
                                         duration: duration,
                                         season: season,
                                         episode: episode,
                                         updatedAt: Date().timeIntervalSince1970)
      return true
    }
    if changed { notify() }
  }

  /// The resume entry for an item, if any (and past the minimum threshold).
  /// A movie (`season == nil`) matches by id alone — there's a single resume point per movie, and
  /// keying it by `episode` (derived from a flaky `videos.first.number`) doesn't round-trip reliably.
  /// A series episode requires an exact `(season, episode)` match.
  func entry(forId id: Int, season: Int?, episode: Int?) -> LocalWatchEntry? {
    lock.lock(); defer { lock.unlock() }
    guard let entry = entries[id], entry.watch.isResumable else { return nil }
    if season == nil {
      return entry.season == nil ? entry : nil
    }
    return (entry.season == season && entry.episode == episode) ? entry : nil
  }

  /// Most-recently-watched first. Includes finished tombstones — Home's overlay needs
  /// them to hide a film / advance a series before the server row refreshes.
  func allEntries() -> [LocalWatchEntry] {
    lock.lock(); defer { lock.unlock() }
    return entries.values
      .filter { $0.watch.state != .unwatched }
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  func clear(id: Int) {
    let changed = mutate { _, entries in
      guard entries[id] != nil else { return false }
      entries[id] = nil
      return true
    }
    if changed { notify() }
  }

  // MARK: - Persistence

  private func load() {
    guard let data = try? Data(contentsOf: fileURL),
          let decoded = try? JSONDecoder().decode([LocalWatchEntry].self, from: data) else { return }
    entries = Dictionary(decoded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
  }

  /// Runs `body` with the lock held. `body` returns whether the file should be rewritten.
  private func mutate(_ body: (inout [Int: MediaItem], inout [Int: LocalWatchEntry]) -> Bool) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    let changed = body(&snapshots, &entries)
    if changed { persist() }
    return changed
  }

  /// Must be called with `lock` held.
  private func persist() {
    guard let data = try? JSONEncoder().encode(Array(entries.values)) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }

  private func notify() {
    NotificationCenter.default.post(name: .localWatchProgressDidChange, object: nil)
  }
}
