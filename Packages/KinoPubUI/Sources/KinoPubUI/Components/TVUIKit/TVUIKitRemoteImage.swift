#if os(tvOS)
//
//  TVUIKitRemoteImage.swift
//  KinoPubUI
//
//  Artwork for the TVUIKit cells. This is a thin face on the shared `Artwork` pipeline,
//  kept because the cells want three UIKit-shaped things the pipeline states differently:
//  a *synchronous* cache probe while a cell is being configured, an async load, and
//  prefetch/cancel driven by `UICollectionViewDataSourcePrefetching`.
//
//  It used to be a hand-written cache — `NSCache` of decoded images keyed by tile size,
//  an actor coalescing in-flight requests, `preparingThumbnail` downsampling. All four
//  behaviours still hold; `Artwork` provides them now, on every platform instead of only
//  this one. See `ArtworkPipeline.swift` for why they are needed at all.
//

import UIKit
import Nuke

public enum TVUIKitRemoteImage {

  /// Prefetching stops at the **data** cache: it downloads bytes and does not decode.
  ///
  /// A cell decodes to its own tile size, and the controller doing the prefetching does
  /// not know that size — decoding here would either fill an Apple TV's memory with
  /// full-resolution art or warm a cache key no cell ever asks for. Bytes are keyed by
  /// URL alone, so warming those helps every size. (The tasks this replaced did decode,
  /// at full resolution, under a key the poster and wide cells never read.)
  ///
  /// Low priority so on-screen art never queues behind art that might scroll into view,
  /// and cancellable — the fire-and-forget tasks were not.
  private static let prefetcher: ImagePrefetcher = {
    let prefetcher = ImagePrefetcher(pipeline: Artwork.pipeline, destination: .diskCache)
    prefetcher.priority = .low
    return prefetcher
  }()

  /// Already-decoded art for this URL at this tile size, or nil. Synchronous on purpose:
  /// a cell calls this while configuring so a recycled tile never paints a placeholder.
  public static func cached(url: URL?, size: CGSize = .zero) -> UIImage? {
    guard let url else { return nil }
    return Artwork.cachedImage(for: url, size: size)
  }

  /// - Parameter size: the tile this art is going into, in points. Artwork is decoded
  ///   down to it — passing `.zero` keeps full resolution and should be rare.
  public static func load(url: URL?, size: CGSize = .zero) async -> UIImage? {
    guard let url else { return nil }
    do {
      let response = try await Artwork.pipeline.imageTask(with: Artwork.request(url, size: size)).response
      ArtworkLog.loaded(url, from: tier(of: response))
      return response.image
    } catch {
      // Missing actor portraits answer 403 by design (see `ActorImageProvider`), so
      // this is a routine line, not an incident.
      ArtworkLog.failed(url, reason: error.localizedDescription)
      return nil
    }
  }

  /// Warm the data cache for art that is about to scroll into view.
  public static func prefetch(_ urls: [URL?]) {
    prefetcher.startPrefetching(with: requests(urls))
  }

  /// Stop warming art that scrolled back out of range before it was needed.
  public static func cancelPrefetch(_ urls: [URL?]) {
    prefetcher.stopPrefetching(with: requests(urls))
  }

  private static func requests(_ urls: [URL?]) -> [ImageRequest] {
    urls.compactMap { $0 }.map { Artwork.request($0) }
  }

  private static func tier(of response: ImageResponse) -> String {
    switch response.cacheType {
    case .memory: return "memory"
    case .disk: return "disk"
    case .none: return "network"
    @unknown default: return "unknown"
    }
  }
}
#endif
