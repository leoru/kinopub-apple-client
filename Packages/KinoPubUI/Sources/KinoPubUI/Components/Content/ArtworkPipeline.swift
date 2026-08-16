//
//  ArtworkPipeline.swift
//  KinoPubUI
//
//  The one artwork cache. Every remote image on every platform goes through this
//  pipeline — `CachedRemoteImage` (SwiftUI), `TVUIKitRemoteImage` (tvOS cells) and
//  `FallbackRemoteImage` are its only callers, and nothing else imports Nuke.
//
//  Why a library and not `AsyncImage`: `URLCache` stores *bytes*. A recycled tile that
//  hits it still pays a full decode, and the default shared cache holds a handful of
//  posters — which is the "posters vanish while you scroll" report. What is needed is a
//  decoded-image memory cache keyed by target size, in-flight coalescing, prefetching
//  and downsampling. tvOS had all four hand-written here; iOS/macOS had none of it.
//  Nuke is that same design, maintained, and it deletes the split.
//
//  Disk holds **original bytes, once per URL** (`.storeOriginalData`). Memory holds the
//  decoded, already-downsampled variants. A rail and a grid asking for the same still at
//  different sizes are two memory entries and one disk entry — which is also what makes
//  the number in Settings › Storage mean something.
//

import Foundation
import CoreGraphics
import SwiftUI
import Nuke

/// Namespace for the shared artwork stack: the pipeline, the request shape, and the
/// cache accounting Settings reports.
public enum Artwork {

  /// Artwork does not share `URLCache` with the API client — the loader's own session
  /// cache is off so bytes are stored once, by `dataCache`, and Storage settings can
  /// report a number that is only artwork.
  public static let pipeline: ImagePipeline = {
    let configuration = URLSessionConfiguration.default
    configuration.urlCache = nil

    return ImagePipeline {
      $0.dataLoader = DataLoader(configuration: configuration)
      $0.dataCache = diskCache
      $0.imageCache = memoryCache
      $0.dataCachePolicy = .storeOriginalData
    }
  }()

  /// Decoded images. On tvOS this is the number that was measured: a 1 MB still decodes
  /// to ~8 MB at full resolution, so 64 MB held about eight of them — at tile size the
  /// same budget holds hundreds, and that is what stopped tiles going blank a short
  /// scroll away. Apple TV HD has little headroom, so the TV budget stays there.
  private static let memoryCache: ImageCache = {
#if os(tvOS)
    let cache = ImageCache(costLimit: 64 * 1024 * 1024, countLimit: 500)
#else
    let cache = ImageCache(costLimit: 256 * 1024 * 1024, countLimit: 2000)
#endif
    return cache
  }()

  /// tvOS purges `Caches/` when the app is not running, so the TV budget is deliberately
  /// small — it is a within-session cache there, and pretending otherwise buys nothing.
  private static let diskCache: DataCache? = {
    guard let cache = try? DataCache(name: "com.soda.kinopub.artwork") else { return nil }
#if os(tvOS)
    cache.sizeLimit = 128 * 1024 * 1024
#else
    cache.sizeLimit = 512 * 1024 * 1024
#endif
    return cache
  }()

  /// - Parameter size: the box this art is going into, in points. Artwork is decoded
  ///   down to it, and the size is part of the cache key — the same still in a rail and
  ///   in a grid is a different decode, and handing one out for the other is either
  ///   blurry or wasteful. `.zero` keeps full resolution and should be rare.
  public static func request(_ url: URL, size: CGSize = .zero) -> ImageRequest {
    guard size != .zero else { return ImageRequest(url: url) }
    return ImageRequest(
      url: url,
      processors: [ImageProcessors.Resize(size: size, unit: .points, contentMode: .aspectFill)]
    )
  }

  /// Already-decoded art at this size, or nil. Synchronous on purpose: a cell calls this
  /// while configuring so a recycled tile never paints a placeholder.
  public static func cachedImage(for url: URL, size: CGSize = .zero) -> PlatformImage? {
    pipeline.cache[request(url, size: size)]?.image
  }

  // MARK: - Accounting, for Settings › Storage

  public static var memoryBytes: Int { memoryCache.totalCost }

  /// Walks the cache directory, so call it off a hot path.
  public static var diskBytes: Int { diskCache?.totalSize ?? 0 }

  public static func clearCaches() {
    memoryCache.removeAll()
    diskCache?.removeAll()
  }
}

extension Image {
  /// `PlatformImage` is `UIImage` on iOS/tvOS and `NSImage` on macOS, and SwiftUI takes
  /// them through different initialisers.
  init(platformImage: PlatformImage) {
#if os(macOS)
    self.init(nsImage: platformImage)
#else
    self.init(uiImage: platformImage)
#endif
  }
}
