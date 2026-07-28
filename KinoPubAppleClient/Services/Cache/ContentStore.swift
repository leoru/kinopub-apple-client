//
//  ContentStore.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubUI
import OSLog
import KinoPubLogging

/// Owns Home/Library rows so views stop re-fetching them on every tab switch. Views
/// read `cards(_:)` synchronously (paints instantly, even offline); callers kick
/// `refreshIfStale`/`refresh` in the background and read again once it resolves.
///
/// Local mutations (`setCards`, `removeCard`) stamp `fetchedAt = now` — a toggle the
/// user just made is not "stale", it's the freshest thing the store knows, and must
/// not be overwritten by a slower in-flight fetch that started before it.
@MainActor
final class ContentStore {
  private(set) var rows: [RowKey: RowState] = [:]
  private var inFlight: [RowKey: Task<Void, Never>] = [:]
  private let disk: RowSnapshotStore

  init(disk: RowSnapshotStore = RowSnapshotStore()) {
    self.disk = disk
    self.rows = disk.loadAll()
  }

  // MARK: - Reading (synchronous, from memory)

  func cards(_ key: RowKey) -> [MediaCard] {
    rows[key]?.cards ?? []
  }

  func isStale(_ key: RowKey) -> Bool {
    guard let state = rows[key] else { return true }
    return Date().timeIntervalSince(state.fetchedAt) > key.ttl
  }

  // MARK: - Refreshing

  /// Runs `fetch` only when the cached row is missing or past its TTL. Callers that
  /// need the resolved cards afterward should read `cards(_:)` again — this just
  /// waits for whichever attempt (this one or one already in flight) to finish.
  func refreshIfStale(_ key: RowKey, fetch: @escaping @Sendable () async throws -> [MediaCard]) async {
    guard isStale(key) else { return }
    await refresh(key, fetch: fetch)
  }

  /// Unconditional refresh (pull-to-refresh). Two callers asking for the same key at
  /// once share one network request instead of firing two.
  func refresh(_ key: RowKey, fetch: @escaping @Sendable () async throws -> [MediaCard]) async {
    if let existing = inFlight[key] {
      await existing.value
      return
    }
    let task = Task { [weak self] in
      guard let self else { return }
      await self.performFetch(key, fetch: fetch)
    }
    inFlight[key] = task
    await task.value
    inFlight[key] = nil
  }

  private func performFetch(_ key: RowKey, fetch: @Sendable () async throws -> [MediaCard]) async {
    do {
      let cards = try await fetch()
      rows[key] = RowState(cards: cards, fetchedAt: Date())
      disk.saveAll(rows)
    } catch {
      // Leave whatever's cached alone: a stale row beats a blank one. Only a caller
      // with nothing at all to draw needs to hear about this — that's `errorHandler`'s
      // job at the call site, not the store's.
      Logger.app.debug("ContentStore: refresh failed for \(String(describing: key)), keeping cached value: \(error)")
    }
  }

  // MARK: - Local mutation

  /// Overwrite a row with a value we already know is current — e.g. after composing
  /// it from several endpoints. Counts as freshly fetched.
  func setCards(_ cards: [MediaCard], for key: RowKey) {
    rows[key] = RowState(cards: cards, fetchedAt: Date())
    disk.saveAll(rows)
  }

  /// Optimistic removal: the card disappears immediately, before the network call
  /// that caused it (hide/mark watched/...) even returns.
  func removeCard(id: Int, from key: RowKey) {
    guard var state = rows[key] else { return }
    state.cards.removeAll { $0.id == id }
    state.fetchedAt = Date()
    rows[key] = state
    disk.saveAll(rows)
  }

  // MARK: - Invalidation

  /// After an action taken elsewhere (toggle bookmark on the detail page, mark
  /// watched, ...) that this store can't see directly: force every row in the family
  /// to refetch next time it's asked for, instead of waiting out its TTL.
  func invalidate(family: RowKey.Family) {
    for key in rows.keys where key.family == family {
      rows[key]?.fetchedAt = .distantPast
    }
  }
}
