//
//  WatchProgress.swift
//  KinoPubBackend
//
//  Single source of truth for "how far through a title is the viewer, and is it finished".
//  Everything — the Continue Watching row, the card badge, the player's end-of-playback handling,
//  the series "next episode" logic — classifies progress through THIS type, so the thresholds live
//  in exactly one place (and are unit-tested) instead of being re-derived with magic numbers.
//
//  Backend note: kino.pub derives a video's watched status server-side from the playback position
//  you report via `/v1/watching/marktime`. So you don't "toggle watched" on a normal finish — you
//  just keep reporting the position, and once it crosses the end tolerance the server treats it as
//  watched and drops it from the watching list. `WatchProgress.isFinished` mirrors that server rule
//  so the client agrees with the server without a round-trip.
//

import Foundation

public struct WatchProgress: Equatable, Hashable {

  /// Seconds watched.
  public let position: Double
  /// Total runtime in seconds. May be 0 or non-finite for live channels / trailers — handled as
  /// "no progress".
  public let duration: Double

  // MARK: Thresholds (the only place these numbers exist)

  /// Below this many seconds a title counts as "not really started" (an accidental tap) and is kept
  /// out of Continue Watching.
  public static let startedSeconds: Double = 10

  /// How close to the end counts as "watched the credits" — a fraction of the runtime, floored and
  /// capped so it's never absurdly short or long, and never more than half the runtime (so short
  /// clips aren't marked finished from the first seconds). Mirrors kino.pub's server-side rule.
  public static func endTolerance(forDuration duration: Double) -> Double {
    let byFraction = min(max(duration * 0.08, 60), 180)
    return min(byFraction, duration * 0.5)
  }

  public enum State: Equatable {
    /// Not started (or below the "started" floor, or no usable duration).
    case unwatched
    /// Started but not finished. Associated value is the fraction watched (0...1).
    case inProgress(Double)
    /// Watched to (or past) the end / credits.
    case finished
  }

  public init(position: Double, duration: Double) {
    self.position = position
    self.duration = duration
  }

  private var hasUsableDuration: Bool { duration.isFinite && duration > 0 }

  /// Fraction watched, clamped to 0...1. `nil` when there's no usable duration (live / trailer).
  public var fraction: Double? {
    guard hasUsableDuration else { return nil }
    return min(max(position / duration, 0), 1)
  }

  /// Past the start floor (and has a real duration) — i.e. intentionally started.
  public var hasStarted: Bool {
    hasUsableDuration && position >= Self.startedSeconds
  }

  /// Watched to the end / credits.
  public var isFinished: Bool {
    guard hasUsableDuration, position > 0 else { return false }
    if position >= duration { return true }
    return position >= duration - Self.endTolerance(forDuration: duration)
  }

  public var state: State {
    guard hasUsableDuration, position > 0 else { return .unwatched }
    if isFinished { return .finished }
    guard hasStarted else { return .unwatched }
    return .inProgress(fraction ?? 0)
  }

  /// Belongs in "Continue Watching": started, but not yet finished.
  public var isResumable: Bool {
    if case .inProgress = state { return true }
    return false
  }
}
