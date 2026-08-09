//
//  BookmarkMembershipStore.swift
//  KinoPubAppleClient
//
//  Local item → bookmark-folder membership. The catalogue payload already carries
//  `MediaItem.bookmarks` (and MediaCard.isBookmarked) — we never need
//  `GET /v1/bookmarks/get-item-folders` just to draw a checkmark. Toggles update
//  this store immediately; server hints fill gaps when the payload had folder ids.
//

import Foundation
import KinoPubBackend

/// Persists which bookmark folders contain which titles. Thread-safe, UserDefaults-backed.
final class BookmarkMembershipStore {

  static let shared = BookmarkMembershipStore()

  private let defaultsKey = "com.soda.kinopub.bookmarkMembership"
  private let lock = NSLock()
  /// itemID → folderIDs. Absent key = "never touched locally, trust the card/payload hint".
  private var map: [Int: Set<Int>] = [:]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    load()
  }

  private let defaults: UserDefaults

  /// Resolved membership: local overlay wins; otherwise the server hint from the card/item.
  func folderIDs(for itemID: Int, serverHint: Set<Int> = []) -> Set<Int> {
    lock.lock(); defer { lock.unlock() }
    return map[itemID] ?? serverHint
  }

  func isBookmarked(_ itemID: Int, serverHint: Set<Int> = []) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return !(map[itemID] ?? serverHint).isEmpty
  }

  /// Replace membership from a trusted payload (`MediaItem.bookmarks` on detail, etc.).
  func replace(itemID: Int, folderIDs: Set<Int>) {
    lock.lock(); defer { lock.unlock() }
    map[itemID] = folderIDs
    persistLocked()
  }

  /// Adopt a non-empty catalogue hint only when we have no local row yet.
  func adoptServerHint(itemID: Int, folderIDs: Set<Int>) {
    guard !folderIDs.isEmpty else { return }
    lock.lock(); defer { lock.unlock() }
    guard map[itemID] == nil else { return }
    map[itemID] = folderIDs
    persistLocked()
  }

  /// Seed from a `MediaItem` when the payload included `bookmarks` (even if empty).
  func seed(from item: MediaItem) {
    guard let bookmarks = item.bookmarks else { return }
    replace(itemID: item.id, folderIDs: Set(bookmarks.map(\.id)))
  }

  @discardableResult
  func toggle(itemID: Int, folderID: Int, serverHint: Set<Int> = []) -> Set<Int> {
    lock.lock(); defer { lock.unlock() }
    var set = map[itemID] ?? serverHint
    if set.contains(folderID) {
      set.remove(folderID)
    } else {
      set.insert(folderID)
    }
    map[itemID] = set
    persistLocked()
    return set
  }

  func clear() {
    lock.lock(); defer { lock.unlock() }
    map = [:]
    defaults.removeObject(forKey: defaultsKey)
  }

  // MARK: - Persistence

  private func load() {
    guard let raw = defaults.dictionary(forKey: defaultsKey) as? [String: [Int]] else { return }
    var loaded: [Int: Set<Int>] = [:]
    for (key, value) in raw {
      guard let id = Int(key) else { continue }
      loaded[id] = Set(value)
    }
    map = loaded
  }

  private func persistLocked() {
    var raw: [String: [Int]] = [:]
    raw.reserveCapacity(map.count)
    for (id, folders) in map {
      raw["\(id)"] = folders.sorted()
    }
    defaults.set(raw, forKey: defaultsKey)
  }
}
