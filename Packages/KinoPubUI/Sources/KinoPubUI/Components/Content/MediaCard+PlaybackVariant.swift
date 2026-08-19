//
//  MediaCard+PlaybackVariant.swift
//  KinoPubUI
//
//  A version of a film as the same landscape card an episode draws.
//
//  Deliberately alongside `MediaCard+Episode` and not a component of its own: a version
//  tile *is* an episode tile — same shape, same progress bar, same watched chip — and it
//  differs in what its caption says. One component, configured.
//

import Foundation
import KinoPubBackend

public extension MediaCard {

  /// - Parameter stillURL: the film's own artwork, used when kino.pub gives the video no
  ///   thumbnail of its own. Two versions of one film usually look identical anyway, so
  ///   the title's still is a truthful stand-in rather than a placeholder.
  init(variant: PlaybackVariant, stillURL: String? = nil) {
    let still = variant.thumbnail.isEmpty ? (stillURL ?? "") : variant.thumbnail
    let isWatched = variant.isWatched
    // Resume bar only while unfinished — a watched version says so with the time chip,
    // the same rule the episode card follows.
    let progress = isWatched ? nil : variant.watchProgress.resumeFraction

    self.init(id: variant.id,
              posterURL: still,
              title: variant.title,
              progress: progress,
              landscapeImageURL: still,
              itemID: variant.mediaId,
              video: variant.number,
              season: nil,
              mediaID: variant.id,
              isWatched: isWatched,
              // Landscape lockup like an episode, but this is a film: `isSeries` drives
              // series-shaped chrome elsewhere and would mislabel it.
              isSeries: false,
              durationSeconds: variant.duration >= 60 ? variant.duration : nil,
              primaryAction: .play)
  }
}
