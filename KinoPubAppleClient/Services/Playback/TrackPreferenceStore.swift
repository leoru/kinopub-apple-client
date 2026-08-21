//
//  TrackPreferenceStore.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

/// **Owns what every scope has learned about dubs and subtitles.** One store, keyed by
/// `TrackMemoryScope.storageKey`; `TrackResolver` reads it and never writes.
///
/// This is the fifth thing that persists per item, and deliberately not part of
/// `MediaLibraryStore`: that one owns optimistic library state the server also knows
/// about (watchlist, watched, votes), and this is local-only knowledge the server has
/// no concept of.
///
/// Rules: docs/product/playback-tracks.md
final class TrackPreferenceStore {

  private static let storageKey = "trackPreferenceLedgers.v1"

  private let defaults: UserDefaults
  private var ledgers: [String: TrackPreferenceLedger]
  /// `PlayerManager` records a play from its periodic time observer, which is not the main
  /// thread, while a card reads a plan on it. Same shape as `LocalWatchProgressStore`.
  private let lock = NSLock()

  /// Bumped on every write. A cached `PlaybackPlan` was decided from this history, so a
  /// change here is what makes it stale — cheaper and more honest than a time-based cache,
  /// which would go stale exactly when the viewer switched dub and expected it to stick.
  private var storedRevision: Int = 0
  var revision: Int {
    lock.lock(); defer { lock.unlock() }
    return storedRevision
  }

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.ledgers = Self.load(from: defaults)
    migrateLegacySubtitleChoicesIfNeeded()
  }

  // MARK: - Reading

  /// One entry per step of the chain, empty where nothing was learned, so the resolver
  /// walks the same shape every time.
  func ledgers(for chain: [TrackMemoryScope]) -> [ScopedLedger] {
    lock.lock(); defer { lock.unlock() }
    return chain.map { scope in
      ScopedLedger(scope: scope, ledger: ledgers[scope.storageKey] ?? TrackPreferenceLedger())
    }
  }

  func ledger(for scope: TrackMemoryScope) -> TrackPreferenceLedger? {
    lock.lock(); defer { lock.unlock() }
    return ledgers[scope.storageKey]
  }

  /// Everything stored, keyed by its raw storage key.
  var all: [String: TrackPreferenceLedger] {
    lock.lock(); defer { lock.unlock() }
    return ledgers
  }

  /// Everything stored, back as scopes — what Settings shows the viewer. A key that no
  /// longer parses is skipped rather than guessed at; it belongs to a scope shape this
  /// build does not have.
  var storedScopes: [TrackMemoryScope: TrackPreferenceLedger] {
    var parsed: [TrackMemoryScope: TrackPreferenceLedger] = [:]
    for (key, ledger) in all {
      guard let scope = TrackMemoryScope(storageKey: key) else { continue }
      parsed[scope] = ledger
    }
    return parsed
  }

  // MARK: - Writing

  /// What this episode offered. Recorded whether or not anything was chosen — "seen" is
  /// about the menu, and it is what lets a dub that arrives later be told apart from one
  /// the viewer has been declining all along.
  func noteMenu(_ tracks: [AudioTrackInfo], in chain: [TrackMemoryScope]) {
    guard !tracks.isEmpty else { return }
    mutate(chain) { $0.noteMenu(tracks) }
  }

  /// One play, worth one unit of weight in every scope that applies. The player calls
  /// this **once per playback session** — on an explicit pick, or once the episode has
  /// been watched far enough to count, whichever happens first.
  func recordAudio(_ signature: AudioTrackSignature,
                   in chain: [TrackMemoryScope],
                   at date: Date = Date()) {
    mutate(chain) { $0.recordAudio(signature, at: date) }
  }

  func recordSubtitle(_ signature: SubtitleChoiceSignature,
                      in chain: [TrackMemoryScope],
                      at date: Date = Date()) {
    mutate(chain) { $0.recordSubtitle(signature, at: date) }
  }

  func forget(scope: TrackMemoryScope) {
    lock.lock()
    ledgers.removeValue(forKey: scope.storageKey)
    persistLocked()
    lock.unlock()
  }

  func forgetEverything() {
    lock.lock()
    ledgers = [:]
    persistLocked()
    lock.unlock()
  }

  // MARK: - Private

  private func mutate(_ chain: [TrackMemoryScope],
                      _ body: (inout TrackPreferenceLedger) -> Void) {
    guard !chain.isEmpty else { return }
    lock.lock(); defer { lock.unlock() }
    for scope in chain {
      var ledger = ledgers[scope.storageKey] ?? TrackPreferenceLedger()
      body(&ledger)
      ledgers[scope.storageKey] = ledger
    }
    persistLocked()
  }

  /// Callers already hold `lock`.
  private func persistLocked() {
    storedRevision &+= 1
    guard let data = try? JSONEncoder().encode(ledgers) else { return }
    defaults.set(data, forKey: Self.storageKey)
  }

  private static func load(from defaults: UserDefaults) -> [String: TrackPreferenceLedger] {
    guard let data = defaults.data(forKey: storageKey),
          let stored = try? JSONDecoder().decode([String: TrackPreferenceLedger].self, from: data)
    else { return [:] }
    return stored
  }

  /// `SubtitleTrackMemory` stored a real language code, so it converts cleanly and is
  /// worth keeping. The old audio memory stored a **rendition display name**, which is
  /// exactly the handle this design replaced — reversing a localized label back into a
  /// language code guesses, so those choices are dropped and re-learned on the next pick.
  private func migrateLegacySubtitleChoicesIfNeeded() {
    let legacyKey = "subtitleTrackChoices"
    guard let data = defaults.data(forKey: legacyKey),
          let choices = try? JSONDecoder().decode([String: SubtitleChoice].self, from: data)
    else { return }

    let migratedAt = Date()
    for (rawID, choice) in choices {
      guard let itemID = Int(rawID) else { continue }
      let scope = TrackMemoryScope.title(id: itemID)
      guard ledgers[scope.storageKey] == nil else { continue }
      let signature: SubtitleChoiceSignature
      if let primary = choice.primary {
        signature = SubtitleChoiceSignature(languageKey: primary.lang, isCC: primary.isCC)
      } else if choice.isEmpty {
        signature = .off
      } else {
        continue
      }
      var ledger = TrackPreferenceLedger()
      ledger.recordSubtitle(signature, at: migratedAt)
      ledgers[scope.storageKey] = ledger
    }

    defaults.removeObject(forKey: legacyKey)
    // Runs from `init`, before any other thread can hold this store.
    persistLocked()
  }
}
