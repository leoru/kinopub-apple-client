//
//  TrackPreferenceDigest.swift
//
//

import Foundation

/// **What the app remembers about tracks, arranged so a person can read it.**
///
/// Not a debug view. A preference that steers playback without ever being shown is a
/// preference the viewer cannot correct, so this exists to say plainly what was learned,
/// where it applies and how strongly — the same grouping the resolver reads in.
///
/// Formatting is here rather than in a view because both platforms' Settings draw it, and
/// a rule that lives in two views is two rules.
public enum TrackPreferenceDigest {

  public struct Entry: Equatable {
    public let label: String
    /// Episodes watched with it. What decides ties, so it is worth showing.
    public let weight: Int
    /// The one this scope would open with, given the choice.
    public let isLeader: Bool

    public init(label: String, weight: Int, isLeader: Bool) {
      self.label = label
      self.weight = weight
      self.isLeader = isLeader
    }
  }

  /// One scope's worth: a season, a series, or the anime bucket.
  public struct Group: Equatable {
    public let scope: TrackMemoryScope
    public let audio: [Entry]
    public let subtitles: [Entry]

    public var isEmpty: Bool { audio.isEmpty && subtitles.isEmpty }
  }

  /// Everything remembered about one title, most specific scope last, plus the class
  /// buckets on their own. `titleID` is nil for a bucket.
  public struct Section: Equatable {
    public let titleID: Int?
    public let groups: [Group]
    /// Episodes watched across every scope in this section — how the sections are ordered,
    /// and a fair answer to "how much does the app actually know about this one".
    public let weight: Int
  }

  /// Sections, heaviest first, with class buckets last.
  ///
  /// A scope that learned nothing is left out entirely: a row saying a series has no
  /// preference is a row that tells the reader nothing.
  public static func sections(from ledgers: [TrackMemoryScope: TrackPreferenceLedger]) -> [Section] {
    var byTitle: [Int?: [Group]] = [:]

    for (scope, ledger) in ledgers {
      let group = Group(scope: scope,
                        audio: entries(from: ledger.audioLadder),
                        subtitles: entries(from: ledger.subtitleLadder))
      guard !group.isEmpty else { continue }
      byTitle[scope.titleID, default: []].append(group)
    }

    let sections = byTitle.map { titleID, groups in
      Section(titleID: titleID,
              groups: groups.sorted(by: isBefore),
              weight: groups.reduce(0) { total, group in
                total + group.audio.reduce(0) { $0 + $1.weight }
              })
    }

    return sections.sorted { lhs, rhs in
      // Buckets are not about any one title, so they read last rather than competing.
      if (lhs.titleID == nil) != (rhs.titleID == nil) { return rhs.titleID == nil }
      if lhs.weight != rhs.weight { return lhs.weight > rhs.weight }
      return (lhs.titleID ?? 0) < (rhs.titleID ?? 0)
    }
  }

  // MARK: - Private

  private static func entries(from ladder: [AudioLedgerEntry]) -> [Entry] {
    ladder.enumerated().map { index, entry in
      Entry(label: entry.signature.displayLabel, weight: entry.weight, isLeader: index == 0)
    }
  }

  private static func entries(from ladder: [SubtitleLedgerEntry]) -> [Entry] {
    ladder.enumerated().map { index, entry in
      Entry(label: entry.signature.displayLabel, weight: entry.weight, isLeader: index == 0)
    }
  }

  /// Broadest first — the series before its seasons before its episodes — because that is
  /// the order the reader thinks in, and the reverse of the order the resolver asks in.
  private static func isBefore(_ lhs: Group, _ rhs: Group) -> Bool {
    rank(lhs.scope) < rank(rhs.scope)
  }

  private static func rank(_ scope: TrackMemoryScope) -> (Int, Int, Int) {
    switch scope {
    case .contentClass: return (0, 0, 0)
    case .title: return (1, 0, 0)
    case let .season(_, season): return (2, season, 0)
    case let .episode(_, season, episode): return (3, season ?? 0, episode)
    }
  }
}
