//
//  NextPlayableEpisodeTests.swift
//
//  What the tvOS Up Next panel offers. The panel itself is AVKit's, but the episode it
//  names is ours — "next in season, else the next season's opener, else nothing".
//

import XCTest
@testable import KinoPubBackend

final class NextPlayableEpisodeTests: XCTestCase {

  private func episode(id: Int, number: Int, title: String = "") -> Episode {
    Episode(id: id, title: title, thumbnail: "", duration: 3064, tracks: 1,
            number: number, ac3: 0, audios: [], watched: 0,
            watching: EpisodeWatching(status: 0, time: 0), subtitles: [], files: [])
  }

  private func season(_ number: Int, episodeIDs: [(id: Int, number: Int)]) -> Season {
    Season(id: number, title: "", number: number,
           watching: SeasonWatching(status: 0),
           episodes: episodeIDs.map { episode(id: $0.id, number: $0.number) })
  }

  private func series(seasons: [Season]) -> MediaItem {
    var item = MediaItem.mock(id: 87940)
    item.seasons = seasons
    return item
  }

  // MARK: - Reading order

  func testNextEpisodeInTheSameSeason() {
    let s1 = season(1, episodeIDs: [(id: 10, number: 1), (id: 11, number: 2)])
    let next = NextPlayableEpisode.after(s1.episodes[0], in: series(seasons: [s1]))
    XCTAssertEqual(next?.id, 11)
  }

  /// A season boundary is not a wall: the season after's first episode is next.
  func testSeasonBoundaryRollsIntoTheNextSeasonsOpener() {
    let s1 = season(1, episodeIDs: [(id: 10, number: 1), (id: 11, number: 2)])
    let s2 = season(2, episodeIDs: [(id: 20, number: 1)])
    let next = NextPlayableEpisode.after(s1.episodes[1], in: series(seasons: [s1, s2]))
    XCTAssertEqual(next?.id, 20)
  }

  /// The payload may arrive unordered; watching order is by number, not by position.
  func testUnorderedPayloadIsReadByNumber() {
    let s2 = season(2, episodeIDs: [(id: 21, number: 2), (id: 20, number: 1)])
    let s1 = season(1, episodeIDs: [(id: 11, number: 2), (id: 10, number: 1)])
    // s1.episodes[0] is *number 2* (id 11) — the tail of season 1, so the answer is
    // season 2's opener wherever the arrays put it.
    let next = NextPlayableEpisode.after(s1.episodes[0], in: series(seasons: [s2, s1]))
    XCTAssertEqual(next?.id, 20)
  }

  // MARK: - Nothing to offer

  func testTheLastEpisodeProposesNothing() {
    let s1 = season(1, episodeIDs: [(id: 10, number: 1)])
    XCTAssertNil(NextPlayableEpisode.after(s1.episodes[0], in: series(seasons: [s1])))
  }

  /// A film's snapshot has no seasons — and no proposal, rather than a guess.
  func testNoSeasonsMeansNoProposal() {
    let s1 = season(1, episodeIDs: [(id: 10, number: 1), (id: 11, number: 2)])
    XCTAssertNil(NextPlayableEpisode.after(s1.episodes[0], in: MediaItem.mock(id: 1)))
    XCTAssertNil(NextPlayableEpisode.after(s1.episodes[0], in: nil))
  }

  /// The episode playing is not in the cached payload (a stale snapshot for another
  /// cut of the series) — nothing to anchor "next" on.
  func testAnUnknownEpisodeProposesNothing() {
    let s1 = season(1, episodeIDs: [(id: 10, number: 1), (id: 11, number: 2)])
    let stranger = episode(id: 99, number: 1)
    XCTAssertNil(NextPlayableEpisode.after(stranger, in: series(seasons: [s1])))
  }

  // MARK: - Stamping the hand-off

  /// A snapshot episode can predate stamping, and the player refuses to report progress
  /// for an unresolved `WatchingMetadata` — so the answer arrives ready to play.
  func testTheAnswerIsStampedForThePlayer() {
    let s1 = season(1, episodeIDs: [(id: 10, number: 1), (id: 11, number: 2)])
    let series = series(seasons: [s1])
    let next = NextPlayableEpisode.after(s1.episodes[0], in: series)
    XCTAssertEqual(next?.mediaId, 87940)
    XCTAssertEqual(next?.seasonNumber, 1)
    XCTAssertEqual(next?.seriesTitle, series.localizedTitle)
    XCTAssertEqual(next?.metadata.isResolved, true)
  }

  /// Stamping fills gaps, it does not overwrite what a caller already knew.
  func testExistingStampsAreKept() {
    let s2 = season(2, episodeIDs: [(id: 20, number: 1)])
    s2.episodes[0].mediaId = 5
    s2.episodes[0].seasonNumber = 7
    s2.episodes[0].seriesTitle = "Already known"
    let s1 = season(1, episodeIDs: [(id: 10, number: 1)])
    let next = NextPlayableEpisode.after(s1.episodes[0], in: series(seasons: [s1, s2]))
    XCTAssertEqual(next?.mediaId, 5)
    XCTAssertEqual(next?.seasonNumber, 7)
    XCTAssertEqual(next?.seriesTitle, "Already known")
  }
}
