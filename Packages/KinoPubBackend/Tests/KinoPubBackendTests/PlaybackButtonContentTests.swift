//
//  PlaybackButtonContentTests.swift
//

import XCTest
@testable import KinoPubBackend

final class PlaybackButtonContentTests: XCTestCase {

  private func episode(number: Int, watched: Int, time: Int = 0, duration: Int = 2400) -> Episode {
    Episode(id: number,
            title: "E\(number)",
            thumbnail: "",
            duration: duration,
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

  private func video(watched: Int, time: Int, duration: Int = 7200) -> Video {
    Video(id: 1,
          title: "",
          thumbnail: "",
          duration: duration,
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

  // MARK: - Films

  func testUnwatchedFilmOffersPlay() {
    XCTAssertEqual(item(videos: [video(watched: 0, time: 0)]).playbackButtonContent, .play(episodeLabel: nil))
  }

  func testPartWatchedFilmOffersResumeWithProgress() {
    let content = item(videos: [video(watched: 0, time: 1800, duration: 7200)]).playbackButtonContent
    XCTAssertEqual(content, .resume(progress: 0.25, episodeLabel: nil, durationSeconds: 7200))
  }

  func testWatchedFilmOffersPlayAgain() {
    XCTAssertEqual(item(videos: [video(watched: 1, time: 7200)]).playbackButtonContent, .playAgain)
  }

  // MARK: - Series

  func testUntouchedSeriesOffersPlayFirstEpisode() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 0), episode(number: 2, watched: 0)])]
    XCTAssertEqual(item(seasons: seasons).playbackButtonContent, .play(episodeLabel: "S1, E1"))
  }

  func testNextUnwatchedEpisodeAfterFinishingOneOffersPlay() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 1), episode(number: 2, watched: 0)])]
    XCTAssertEqual(item(seasons: seasons).playbackButtonContent, .play(episodeLabel: "S1, E2"))
  }

  func testEpisodeInProgressOffersResumeWithProgress() {
    let seasons = [season(1, episodes: [episode(number: 2, watched: 0, time: 600, duration: 2400)])]
    let content = item(seasons: seasons).playbackButtonContent
    XCTAssertEqual(content, .resume(progress: 0.25, episodeLabel: "S1, E2", durationSeconds: 2400))
  }

  func testFullyWatchedSeriesOffersPlayAgain() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 1), episode(number: 2, watched: 1)])]
    XCTAssertEqual(item(seasons: seasons).playbackButtonContent, .playAgain)
  }

  func testPrimaryEpisodeSkipsWatchedOnes() {
    let seasons = [season(1, episodes: [episode(number: 1, watched: 1), episode(number: 2, watched: 0)])]
    let primary = item(seasons: seasons).primaryEpisode
    XCTAssertEqual(primary?.season.number, 1)
    XCTAssertEqual(primary?.episode.number, 2)
  }
}
