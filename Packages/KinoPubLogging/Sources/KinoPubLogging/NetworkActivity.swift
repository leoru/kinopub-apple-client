//
//  NetworkActivity.swift
//  KinoPubLogging
//
//  What is in flight *right now*, by product name.
//
//  Pulse answers "what came back and how"; it writes its record when a task completes,
//  so it cannot answer "what are we still waiting for" — which is the question an empty
//  loader on Apple TV raises and never answers. This registry is that second channel:
//  work registers a named activity and unregisters when it settles, and a debug overlay
//  renders whatever is currently registered.
//
//  Names are product words ("History", "Watchlist", "Session"), not endpoint paths —
//  the point is a person reading a screen, not a trace.
//

import Foundation
import Combine

@MainActor
public final class NetworkActivity: ObservableObject {
  public static let shared = NetworkActivity()

  public struct Entry: Identifiable, Sendable {
    public let id: UUID
    /// Localization key, resolved against the app bundle. This is what a person reads on
    /// the launch screen, which is why it is a key and not a formatted string — the raw
    /// endpoint must never reach a user-facing label.
    public let nameKey: String
    /// The endpoint path. Debug overlay only.
    public let detail: String
    public let startedAt: Date

    public func elapsed(at now: Date = Date()) -> TimeInterval {
      now.timeIntervalSince(startedAt)
    }
  }

  /// Oldest first, so an overlay reads as a queue and the slow one stays at the top.
  @Published public private(set) var inFlight: [Entry] = []

  /// `end` can land before its `begin` — both hop to the main actor and the hops are not
  /// ordered. Without this the entry would never be removed and the overlay would grow a
  /// permanent ghost row, which is exactly the kind of lie a diagnostic must not tell.
  private var endedEarly: Set<UUID> = []

  private init() {}

  /// - Returns: the token to hand back to `end`.
  public nonisolated static func begin(nameKey: String, detail: String = "") -> UUID {
    let entry = Entry(id: UUID(), nameKey: nameKey, detail: detail, startedAt: Date())
    Task { @MainActor in shared.append(entry) }
    return entry.id
  }

  public nonisolated static func end(_ token: UUID) {
    Task { @MainActor in shared.remove(token) }
  }

  private func append(_ entry: Entry) {
    guard endedEarly.remove(entry.id) == nil else { return }
    inFlight.append(entry)
  }

  private func remove(_ token: UUID) {
    guard let index = inFlight.firstIndex(where: { $0.id == token }) else {
      endedEarly.insert(token)
      return
    }
    inFlight.remove(at: index)
  }
}
