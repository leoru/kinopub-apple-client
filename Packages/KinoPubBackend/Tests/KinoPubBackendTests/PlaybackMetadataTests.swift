//
//  PlaybackMetadataTests.swift
//
//  What the system player is told about what is playing. The panel itself cannot be
//  asserted without a device, but what we hand it can — and the bug this covers was
//  handing it almost nothing whenever the thing playing was an episode.
//

import AVFoundation
import XCTest
@testable import KinoPubBackend

final class PlaybackMetadataTests: XCTestCase {

  private func value(_ identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) -> String? {
    items.first { $0.identifier == identifier }?.stringValue
  }

  /// The mock ships empty poster strings, so artwork is given explicitly where it matters.
  private var series: MediaItem { MediaItem.mock() }
  private var poster: Posters {
    Posters(small: "https://e.x/s.jpg", medium: "https://e.x/m.jpg",
            big: "https://e.x/b.jpg", wide: "https://e.x/w.jpg")
  }

  // MARK: - What reaches the panel

  func testTheTitleAndSubtitleAreCarriedAsThemselves() {
    let items = PlaybackMetadata.items(title: "Breaking Bad",
                                       subtitle: "Season 2, Episode 5 — Breakage",
                                       context: nil)
    XCTAssertEqual(value(.commonIdentifierTitle, in: items), "Breaking Bad")
    XCTAssertEqual(value(.iTunesMetadataTrackSubTitle, in: items), "Season 2, Episode 5 — Breakage")
  }

  /// The whole point: an episode has no plot, no genres and no year of its own, so the
  /// series it belongs to is what fills the panel.
  func testTheSeriesFillsAnEpisodesPanel() {
    let items = PlaybackMetadata.items(title: "Series",
                                       subtitle: "Season 1, Episode 2",
                                       context: series)
    XCTAssertEqual(value(.commonIdentifierDescription, in: items), series.plot)
    XCTAssertEqual(value(.commonIdentifierCreationDate, in: items), "2023")
    XCTAssertEqual(value(.commonIdentifierType, in: items),
                   "Comedy, Action, Fantastic, Adventure")
  }

  /// Without the series — a cold launch straight into a download, say — the two lines we
  /// do know still go, rather than nothing.
  func testNoContextStillCarriesTheLines() {
    let items = PlaybackMetadata.items(title: "Film", subtitle: nil, context: nil)
    XCTAssertEqual(items.count, 1)
    XCTAssertEqual(value(.commonIdentifierTitle, in: items), "Film")
  }

  /// An empty string in the panel is worse than an absent line: it reserves the space.
  func testNothingEmptyIsSent() {
    let bare = MediaItem.mock().replacing(plot: "", genres: [], year: 0)
    let items = PlaybackMetadata.items(title: "", subtitle: "", context: bare)
    XCTAssertTrue(items.isEmpty)
  }

  // MARK: - Artwork

  func testTheBiggestPosterWins() {
    let withPoster = series.replacing(posters: poster)
    XCTAssertEqual(PlaybackMetadata.artworkURL(context: withPoster)?.absoluteString,
                   "https://e.x/b.jpg")
  }

  /// A title whose big poster never arrived still has something to show.
  func testASmallerPosterIsUsedWhenTheBigOneIsMissing() {
    let partial = series.replacing(posters: Posters(small: "https://e.x/s.jpg", medium: "",
                                                    big: "", wide: ""))
    XCTAssertEqual(PlaybackMetadata.artworkURL(context: partial)?.absoluteString,
                   "https://e.x/s.jpg")
  }

  /// An episode still is the last resort, not a competitor: a cached series poster wins.
  func testThePosterBeatsTheEpisodeStill() {
    let withPoster = series.replacing(posters: poster)
    XCTAssertEqual(PlaybackMetadata.artworkURL(context: withPoster,
                                               fallback: "https://e.x/still.jpg")?.absoluteString,
                   "https://e.x/b.jpg")
  }

  /// A series that is no longer cached leaves the episode's own still, which is the frame
  /// the rail was showing a moment before.
  func testAnEpisodeStillStandsInForAMissingSeries() {
    let url = PlaybackMetadata.artworkURL(context: nil, fallback: "https://e.x/still.jpg")
    XCTAssertEqual(url?.absoluteString, "https://e.x/still.jpg")
  }

  func testNoArtworkAtAllIsNil() {
    XCTAssertNil(PlaybackMetadata.artworkURL(context: nil, fallback: "  "))
  }

  // MARK: - Shape

  /// Tagging these with a language makes AVFoundation filter them against the viewer's
  /// own locale, and the panel then shows nothing.
  func testEverythingIsLanguageNeutral() {
    let items = PlaybackMetadata.items(title: "T", subtitle: "S", context: series)
    XCTAssertFalse(items.isEmpty)
    for item in items {
      XCTAssertEqual(item.extendedLanguageTag, "und")
    }
  }
}

private extension MediaItem {
  func replacing(plot: String? = nil,
                 genres: [TypeClass]? = nil,
                 year: Int? = nil,
                 posters: Posters? = nil) -> MediaItem {
    let plot = plot ?? self.plot
    let genres = genres ?? self.genres
    let year = year ?? self.year
    let posters = posters ?? self.posters
    return MediaItem(id: id, type: type, subtype: subtype, title: title, year: year, cast: cast,
              director: director, genres: genres, countries: countries, voice: voice,
              duration: duration, langs: langs, quality: quality, plot: plot, imdb: imdb,
              imdbRating: imdbRating, imdbVotes: imdbVotes, kinopoisk: kinopoisk,
              kinopoiskRating: kinopoiskRating, kinopoiskVotes: kinopoiskVotes, rating: rating,
              ratingVotes: ratingVotes, ratingPercentage: ratingPercentage, views: views,
              comments: comments, posters: posters, trailer: trailer, finished: finished,
              advert: advert, poorQuality: poorQuality, createdAt: createdAt,
              updatedAt: updatedAt, inWatchlist: inWatchlist, subscribed: subscribed, ac3: ac3,
              bookmarks: bookmarks, seasons: seasons, videos: videos)
  }
}
