//
//  MediaCard+LandscapeArtwork.swift
//  KinoPubUI
//
//  One rule for what goes in a 16:9 card, shared by Continue Watching and History.
//
//  They used to pick differently and it showed. History preferred the episode still —
//  a real 16:9 frame the API always sends for an episode. Continue Watching went
//  straight for the title's wide poster, and `Posters.wideURL` *derives* that path by
//  swapping `/item/big/` for `/item/wide/` whether or not kino.pub actually has one.
//  When it does not, the URL 404s and the card falls back to a placeholder — so one
//  row held proper stills next to blank tiles, which is the "different aspect ratios"
//  that was really different artwork.
//
//  The card box itself never varies: `CardAspect.landscape` is 16:9 and the image is
//  drawn `.fill` inside it. What varies is whether the source was shaped for that box.
//

import Foundation
import KinoPubBackend

public extension MediaCard {

  /// Artwork for a 16:9 card.
  ///
  /// - Parameters:
  ///   - episodeStill: `media.thumbnail` — a frame from the episode being watched.
  ///   - posters: the title's own artwork.
  ///   - isSeries: episodes get their still; a film's "still" is a frame grab from the
  ///     middle of it, and the wide poster is artwork someone actually composed.
  /// - Returns: nil when there is nothing 16:9-shaped to show, so the caller can draw
  ///   a poster card rather than crop a 2:3 image into a landscape box.
  static func landscapeArtwork(episodeStill: String?,
                               posters: Posters?,
                               isSeries: Bool) -> String? {
    let still = episodeStill.flatMap { $0.isEmpty ? nil : $0 }
    let wide = posters?.wideURL.flatMap { $0.isEmpty ? nil : $0 }
    return isSeries ? (still ?? wide) : (wide ?? still)
  }
}
