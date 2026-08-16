//
//  PlaybackVariant.swift
//  KinoPubBackend
//
//  The *same* film, encoded differently: 24 fps / 48 fps, colour / black-and-white,
//  theatrical / director's cut.
//
//  kino.pub ships these as the `videos` array of a `subtype: "multi"` movie — several
//  entries with `snumber: 0`, their own `id`, and a human name in `title` ("24 fps").
//  Until now only `videos.first` was ever read, so a title with two versions played one
//  of them and the other was unreachable.
//
//  A variant is a `PlayableItem`, like `Episode` is, and for the same reason: the rail
//  that lists them and the player that opens them should not care which of the two they
//  were handed. It carries its parent's id and title the way `Episode` carries
//  `mediaId` / `seriesTitle` — the API sends the video with none of that context.
//
//  Not a season, and not an episode. Real episodes live under `seasons`; these must
//  never reach that rail as siblings of them.
//

import Foundation

public struct PlaybackVariant: Identifiable, Hashable {
  public let video: Video
  /// The film this is a version of — what `watching` is reported against.
  public let mediaId: Int
  public let movieTitle: String

  public init(video: Video, mediaId: Int, movieTitle: String) {
    self.video = video
    self.mediaId = mediaId
    self.movieTitle = movieTitle
  }

  public var id: Int { video.id }
  public var number: Int { video.number }
  public var duration: Int { video.duration }
  public var thumbnail: String { video.thumbnail }
  public var watchProgress: WatchProgress { video.watchProgress }
  public var isWatched: Bool { video.isWatched }

  /// kino.pub names these well ("24 fps", "48 fps"), so the name is the label. The
  /// numbered fallback is for the rare payload that leaves it blank — "Version 2" still
  /// distinguishes it from its sibling, which is the whole job of this string.
  public var title: String {
    let trimmed = video.title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Version \(video.number)" : trimmed
  }
}

extension PlaybackVariant: PlayableItem {
  public var files: [FileInfo] { video.files }
  public var trailer: Trailer? { nil }
  public var subtitles: [Subtitle] { video.subtitles }

  /// `video: number`, `season: nil` — the shape `MediaItem` already reports for a film.
  /// A variant is a different *video* of the same item, not a different item.
  public var metadata: WatchingMetadata {
    WatchingMetadata(id: mediaId, video: video.number, season: nil)
  }

  public var audioTracks: [AudioTrackInfo] { AudioTracks.catalog(video.audios) }
}
