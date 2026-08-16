//
//  MediaLinksResolver.swift
//  KinoPubAppleClient
//
//  Fills in the video links a `nolinks=1` details call left out.
//
//  A series detail response carries a full link ladder for every episode of every
//  season — on a long-running show that is most of the payload, and at most one
//  episode's worth is ever used. So the detail page asks for the item without links
//  (`ItemDetailsRequest(excludeLinks:)`) and the links for a single episode are fetched
//  here, from `/v1/items/media-links?mid=`, at the moment that episode is needed.
//
//  `Episode` is a class, so filling one is visible to everyone already holding it: the
//  seasons rail, the player, next-episode. A second play costs no second request.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

@MainActor
final class MediaLinksResolver {

  static let shared = MediaLinksResolver()

  /// One request per media id, however many callers ask at once.
  private var inFlight: [Int: Task<MediaLinks?, Never>] = [:]

  /// Gives `episode` its files and subtitles if it has none. Returns false when the
  /// episode still has nothing playable afterwards — the caller shows the failure, this
  /// does not throw over a stream that may yet be resolvable from a local download.
  @discardableResult
  func fill(_ episode: Episode, using service: VideoContentService) async -> Bool {
    // Not `files.isEmpty`: a `nolinks=1` payload still lists the quality ladder, it just
    // gives no links for any rung of it.
    guard !episode.files.hasPlayableURLs else { return true }
    guard let links = await links(forMediaId: episode.id, using: service) else { return false }
    episode.files = links.files
    // `nolinks` is documented as dropping video links; whether it also drops subtitle
    // links is not, so only fill what is actually missing.
    if episode.subtitles.isEmpty {
      episode.subtitles = links.subtitles
    }
    Logger.app.info(
      "media-links mid=\(episode.id) files=\(links.files.count) subs=\(links.subtitles.count) best=\(links.files.first?.quality ?? "none")"
    )
    return episode.files.hasPlayableURLs
  }

  func links(forMediaId id: Int, using service: VideoContentService) async -> MediaLinks? {
    if let existing = inFlight[id] { return await existing.value }
    let task = Task<MediaLinks?, Never> {
      do {
        return try await service.fetchMediaLinks(mediaId: id)
      } catch {
        Logger.app.error("media-links failed for \(id): \(error)")
        return nil
      }
    }
    inFlight[id] = task
    let result = await task.value
    inFlight[id] = nil
    return result
  }
}
