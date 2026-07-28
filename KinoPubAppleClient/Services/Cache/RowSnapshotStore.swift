//
//  RowSnapshotStore.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubUI

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
    self.fileURL = dir.appendingPathComponent("rows.json")
  }

  func loadAll() -> [RowKey: RowState] {
    guard let data = try? Data(contentsOf: fileURL),
          let stored = try? decoder.decode([StoredRow].self, from: data) else { return [:] }
    return Dictionary(uniqueKeysWithValues: stored.map { ($0.key, $0.state) })
  }

  func saveAll(_ rows: [RowKey: RowState]) {
    let stored = rows.map { StoredRow(key: $0.key, state: $0.value) }
    guard let data = try? encoder.encode(stored) else { return }
    try? data.write(to: fileURL, options: [.atomic])
  }
}
