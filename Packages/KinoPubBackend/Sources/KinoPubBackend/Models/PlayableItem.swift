//
//  PlayableItem.swift
//
//
//  Created by Kirill Kunst on 9.11.2023.
//

import Foundation

public protocol PlayableItem: Identifiable, Hashable, Equatable {
  var id: Int { get }
  var files: [FileInfo] { get }
  var trailer: Trailer? { get }
  var metadata: WatchingMetadata { get }
  var subtitles: [Subtitle] { get }
  /// API audio metadata for this playable — used to label HLS renditions in the
  /// system Audio picker. Empty when we don't have it (offline downloads).
  var audioTracks: [AudioTrackInfo] { get }
}

public extension PlayableItem {
  /// A trailer is only offerable when the API actually gave us a link — `trailer`
  /// can be present with a nil or empty `url`.
  var trailerURL: URL? {
    guard let url = trailer?.url, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    return URL(string: url)
  }

  var audioTracks: [AudioTrackInfo] { [] }
}
