//
//  ContinueWatchingLocalOverlay.swift
//

import Foundation

/// How local resume points paint the Continue Watching row **without** touching
/// `ContentStore`'s TTL. The cached cards stay the last server-backed snapshot;
/// this plan is applied at read time so a progress bar (or a just-finished hide)
/// can move on the next assemble, not on the next 60s refresh.
///
/// The player writes `LocalWatchProgressStore` every ~10s. Home must not persist
/// those ticks back into `rows-v2.json` — that is what the cache is for, and
/// rewriting it from a playhead would be the opposite of trusting it.
public enum ContinueWatchingLocalOverlay {

  public struct Card: Equatable, Sendable {
    public var itemID: Int
    public var isSeries: Bool
    public var season: Int?
    public var video: Int?

    public init(itemID: Int, isSeries: Bool, season: Int?, video: Int?) {
      self.itemID = itemID
      self.isSeries = isSeries
      self.season = season
      self.video = video
    }
  }

  public struct Local: Equatable, Sendable {
    public var itemID: Int
    public var isSeries: Bool
    public var season: Int?
    public var episode: Int?
    public var isFinished: Bool
    public var isResumable: Bool
    public var progress: Double?
    public var updatedAt: TimeInterval
    /// Snapshot exists so a title the server has not listed yet can still draw a card.
    public var canInsert: Bool

    public init(itemID: Int,
                isSeries: Bool,
                season: Int?,
                episode: Int?,
                isFinished: Bool,
                isResumable: Bool,
                progress: Double?,
                updatedAt: TimeInterval,
                canInsert: Bool) {
      self.itemID = itemID
      self.isSeries = isSeries
      self.season = season
      self.episode = episode
      self.isFinished = isFinished
      self.isResumable = isResumable
      self.progress = progress
      self.updatedAt = updatedAt
      self.canInsert = canInsert
    }
  }

  public struct Mutation: Equatable, Sendable {
    public var progress: Double?
    public var season: Int?
    public var video: Int?
    public var overlayLabel: String?

    public init(progress: Double?, season: Int?, video: Int?, overlayLabel: String?) {
      self.progress = progress
      self.season = season
      self.video = video
      self.overlayLabel = overlayLabel
    }
  }

  public struct Plan: Equatable, Sendable {
    public var hiddenIDs: Set<Int>
    public var mutations: [Int: Mutation]
    /// Painted order: recently-touched local titles first, then the rest of the
    /// cached row. Inserts (local-only) are included.
    public var order: [Int]
    public var insertIDs: [Int]

    public init(hiddenIDs: Set<Int>,
                mutations: [Int: Mutation],
                order: [Int],
                insertIDs: [Int]) {
      self.hiddenIDs = hiddenIDs
      self.mutations = mutations
      self.order = order
      self.insertIDs = insertIDs
    }
  }

  public static func plan(cards: [Card], locals: [Local]) -> Plan {
    let cardByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.itemID, $0) })
    let recents = locals.sorted { $0.updatedAt > $1.updatedAt }

    var hidden = Set<Int>()
    var mutations: [Int: Mutation] = [:]
    var insertIDs: [Int] = []

    for local in recents {
      let card = cardByID[local.itemID]
      let present = card != nil

      if local.isFinished, !local.isSeries {
        if present { hidden.insert(local.itemID) }
        continue
      }

      if local.isFinished, local.isSeries {
        let next = ContinueWatchingEpisode.forSeries(
          local: (local.season, local.episode, true),
          history: nil,
          finishedInSeason: local.episode.map { [$0] } ?? [],
          watchedCount: nil,
          total: nil
        )
        guard next.hasEpisode else {
          if present { hidden.insert(local.itemID) }
          continue
        }
        let season = next.season ?? local.season ?? card?.season
        let video = next.episode
        let mutation = Mutation(
          progress: nil,
          season: season,
          video: video,
          overlayLabel: ContinueWatchingEpisode.overlayLabel(season: season, episode: video)
        )
        if present {
          mutations[local.itemID] = mutation
        }
        // Do not insert a finished series the row already dropped — without a
        // season map we would invent E+1 forever after the title left watching.
        continue
      }

      guard local.isResumable else { continue }
      let season = local.season ?? card?.season
      let video = local.episode ?? card?.video
      let mutation = Mutation(
        progress: local.progress,
        season: season,
        video: video,
        overlayLabel: local.isSeries
          ? ContinueWatchingEpisode.overlayLabel(season: season, episode: video)
          : nil
      )
      if present {
        mutations[local.itemID] = mutation
      } else if local.canInsert {
        insertIDs.append(local.itemID)
        mutations[local.itemID] = mutation
      }
    }

    var order: [Int] = []
    var seen = Set<Int>()
    for local in recents {
      let id = local.itemID
      if hidden.contains(id) { continue }
      let inRow = cardByID[id] != nil || insertIDs.contains(id)
      guard inRow, seen.insert(id).inserted else { continue }
      order.append(id)
    }
    for card in cards {
      if hidden.contains(card.itemID) { continue }
      if seen.insert(card.itemID).inserted {
        order.append(card.itemID)
      }
    }

    return Plan(hiddenIDs: hidden, mutations: mutations, order: order, insertIDs: insertIDs)
  }
}
