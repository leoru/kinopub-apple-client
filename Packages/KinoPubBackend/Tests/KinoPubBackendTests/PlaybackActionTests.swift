//
//  PlaybackActionTests.swift
//
//

import XCTest
@testable import KinoPubBackend

final class PlaybackActionTests: XCTestCase {

  // MARK: - Builders

  private func episode(number: Int, watched: Int, time: Int = 0) -> Episode {
    Episode(id: number,
            title: "E\(number)",
            thumbnail: "",
            duration: 2400,
            tracks: 1,
            number: number,
            ac3: 0,
            audios: [],
            watched: watched,
            watching: EpisodeWatching(status: 0, time: time),
            subtitles: [],
            files: [])
  }

  private func season(_ number: Int, episodes: [Episode]) -> Season {
    Season(id: number,
           title: "S\(number)",
           number: number,
           watching: SeasonWatching(status: 0),
           episodes: episodes)
  }

  private func video(watched: Int, time: Int) -> Video {
    Video(id: 1,
          title: "",
          thumbnail: "",
          duration: 7200,
          tracks: 1,
          number: 1,
          ac3: 0,
          audios: [],
          watched: watched,
          watching: EpisodeWatching(status: 0, time: time),
          subtitles: [],
          files: [])
  }

  private func item(seasons: [Season]? = nil, videos: [Video]? = nil) -> MediaItem {
    var item = MediaItem.mock()
    item.seasons = seasons
    return MediaItem(id: item.id, type: item.type, subtype: item.subtype, title: item.title,
                     year: item.year, cast: item.cast, director: item.director, genres: item.genres,
                     countries: item.countries, voice: item.voice, duration: item.duration,
                     langs: item.langs, quality: item.quality, plot: item.plot, imdb: item.imdb,
                     imdbRating: item.imdbRating, imdbVotes: item.imdbVotes, kinopoisk: item.kinopoisk,
                     kinopoiskRating: item.kinopoiskRating, kinopoiskVotes: item.kinopoiskVotes,
                     rating: item.rating, ratingVotes: item.ratingVotes,
                     ratingPercentage: item.ratingPercentage, views: item.views,
                     comments: item.comments, posters: item.posters, trailer: item.trailer,
                     finished: item.finished, advert: item.advert, poorQuality: item.poorQuality,
                     createdAt: item.createdAt, updatedAt: item.updatedAt,
                     inWatchlist: item.inWatchlist, subscribed: item.subscribed, ac3: item.ac3,
                     bookmarks: item.bookmarks, seasons: seasons, videos: videos)
  }

  // MARK: - isSeries

  /// Regression: `seasons` is nil for films, and the old `?? false` default made
  /// every film report as a series.
  func testFilmIsNotASeries() {
    XCTAssertFalse(item(videos: [video(watched: 0, time: 0)]).isSeries)
  }

  func testItemWithSeasonsIsASeries() {
    XCTAssertTrue(item(seasons: [season(1, episodes: [episode(number: 1, watched: 0)])]).isSeries)
  }

  // MARK: - Films

  func testUnwatchedFilmOffersPlay() {
    XCTAssertEqual(item(videos: [video(watched: 0, time: 0)]).playbackAction, .play)
  }

  func testPartWatchedFilmOffersContinue() {
    XCTAssertEqual(item(videos: [video(watched: 0, time: 1200)]).playbackAction, .resume)
  }

  func testWatchedFilmOffersPlayAgain() {
    XCTAssertEqual(item(videos: [video(watched: 1, time: 7200)]).playbackAction, .playAgain)
  }

  func testFilmWithoutVideosFallsBackToPlay() {
    XCTAssertEqual(item().playbackAction, .play)
  }

  // MARK: - Series

  func testUntouchedSeriesOffersPlay() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 0), episode(number: 2, watched: 0)])]
    XCTAssertEqual(item(seasons: seasons).playbackAction, .play)
  }

  func testPartWatchedSeriesOffersContinue() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 1), episode(number: 2, watched: 0)])]
    XCTAssertEqual(item(seasons: seasons).playbackAction, .resume)
  }

  /// An episode left mid-way counts even when nothing is marked watched.
  func testSeriesWithAnEpisodeInProgressOffersContinue() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 0, time: 600)])]
    XCTAssertEqual(item(seasons: seasons).playbackAction, .resume)
  }

  func testFullyWatchedSeriesOffersPlayAgain() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 1), episode(number: 2, watched: 1)])]
    XCTAssertEqual(item(seasons: seasons).playbackAction, .playAgain)
  }

  func testFullyWatchedAcrossSeveralSeasons() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 1)]),
                   season(2, episodes: [episode(number: 1, watched: 1)])]
    XCTAssertEqual(item(seasons: seasons).playbackAction, .playAgain)
  }

  func testSeriesWithNoEpisodesFallsBackToPlay() {
    XCTAssertEqual(item(seasons: [season(1, episodes: [])]).playbackAction, .play)
  }
}
