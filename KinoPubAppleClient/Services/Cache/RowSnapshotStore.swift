//
//  RowSnapshotStore.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubLogging
import KinoPubUI
import OSLog

/// One cached row: its cards and when they were last fetched. No pagination here —
/// these are the fixed-size summary rows on Home/Library, not the paginated grids.
struct RowState: Codable {
  var cards: [MediaCard]
  var fetchedAt: Date
}

/// Persists `ContentStore`'s rows to a single JSON file in `Caches/`, so a cold start
/// paints yesterday's rows before the network answers. `Caches/` is purged by the OS
/// when the app isn't running (tvOS in particular) — that's fine, the store treats a
/// missing snapshot exactly like an empty one and refetches.
final class RowSnapshotStore {
  private struct StoredRow: Codable {
    let key: RowKey
    let state: RowState
  }

  private let fileURL: URL
  private let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()

  init(directory: URL? = nil) {
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let dir = directory ?? caches.appendingPathComponent("KinoPubContentStore", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    // Versioned filename. A snapshot written before `MediaCard.watchedAt` existed
    // decodes cleanly with a nil date, which is worse than not decoding at all: the
    // whole history list silently files itself under "Earlier" until the TTL expires.
    // Bumping the name retires those snapshots instead of reasoning about them.
    self.fileURL = dir.appendingPathComponent("rows-v2.json")
  }

  func loadAll() -> [RowKey: RowState] {
    guard let data = try? Data(contentsOf: fileURL),
          let stored = try? decoder.decode([StoredRow].self, from: data) else { return [:] }
    return Dictionary(uniqueKeysWithValues: stored.map { ($0.key, $0.state) })
  }

  func saveAll(_ rows: [RowKey: RowState]) {
    let stored = rows.map { StoredRow(key: $0.key, state: $0.value) }
    do {
      let data = try encoder.encode(stored)
      try data.write(to: fileURL, options: [.atomic])
    } catch {
      Logger.app.error("RowSnapshotStore: save failed: \(error.localizedDescription)")
    }
  }

  /// Bytes on disk — for the Settings storage screen. 0 when there is no snapshot yet.
  var diskUsage: Int64 {
    let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
    return (attributes?[.size] as? Int64) ?? 0
  }

  /// Deletes the snapshot file. The next `loadAll()` simply sees an empty cache and refetches.
  func clear() {
    try? FileManager.default.removeItem(at: fileURL)
  }
}
