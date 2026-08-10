#if os(tvOS)
//
//  TVUIKitRemoteImage.swift
//  KinoPubUI
//
//  Artwork for the TVUIKit cells: a decoded-image memory cache in front of the shared
//  `URLCache`, with in-flight coalescing and prefetching.
//
//  The memory cache is the point. `URLCache` stores *bytes*, and its default memory
//  capacity holds only a handful of posters, so a recycled cell used to come back to a
//  blank tile and re-download art that was on screen a second earlier — the "posters
//  vanish while you scroll" report. A cell can now ask `cached(url:)` synchronously
//  while it is being configured and repaint in the same frame, so recycling stops
//  being visible at all.
//
//  Decoding happens off the main thread (`preparingForDisplay()`); `UIImage(data:)`
//  alone defers it to the first draw, which is a frame drop per tile on a rail.
//

import UIKit

public enum TVUIKitRemoteImage {

  /// Decoded images, keyed by URL. `NSCache` is thread-safe and evicts itself under
  /// memory pressure, which is the behaviour we want on an Apple TV HD.
  private static let memory: NSCache<NSURL, UIImage> = {
    let cache = NSCache<NSURL, UIImage>()
    cache.name = "TVUIKitRemoteImage"
    cache.totalCostLimit = 64 * 1024 * 1024
    return cache
  }()

  /// Already-decoded art for this URL, or nil. Synchronous on purpose: a cell calls
  /// this while configuring so a recycled tile never paints a placeholder first.
  public static func cached(url: URL?) -> UIImage? {
    guard let url else { return nil }
    return memory.object(forKey: url as NSURL)
  }

  public static func load(url: URL?) async -> UIImage? {
    guard let url else { return nil }
    if let hit = cached(url: url) { return hit }
    return await ArtworkFetcher.shared.image(for: url)
  }

  /// Warm the cache for art that is about to scroll into view. Fire-and-forget: the
  /// results land in `memory`, and the cell that eventually needs one finds it there.
  public static func prefetch(_ urls: [URL?]) {
    for case let url? in urls where cached(url: url) == nil {
      Task.detached(priority: .utility) { _ = await load(url: url) }
    }
  }

  fileprivate static func store(_ image: UIImage, for url: URL) {
    let pixels = image.size.width * image.scale * image.size.height * image.scale
    memory.setObject(image, forKey: url as NSURL, cost: Int(pixels) * 4)
  }
}

/// Coalesces concurrent requests for the same URL. Without it, a rail that configures
/// eight cells for the same missing poster fires eight identical downloads.
private actor ArtworkFetcher {
  static let shared = ArtworkFetcher()

  private var inFlight: [URL: Task<UIImage?, Never>] = [:]

  func image(for url: URL) async -> UIImage? {
    if let existing = inFlight[url] { return await existing.value }
    let task = Task<UIImage?, Never> { await Self.fetch(url) }
    inFlight[url] = task
    let image = await task.value
    inFlight[url] = nil
    if let image { TVUIKitRemoteImage.store(image, for: url) }
    return image
  }

  private static func fetch(_ url: URL) async -> UIImage? {
    var request = URLRequest(url: url)
    request.cachePolicy = .returnCacheDataElseLoad
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
        // Missing actor portraits answer 403 by design (see `ActorImageProvider`), so
        // this is a routine line, not an incident.
        ArtworkLog.failed(url, reason: "HTTP \(http.statusCode)")
        return nil
      }
      guard let image = UIImage(data: data) else {
        ArtworkLog.failed(url, reason: "undecodable (\(data.count) bytes)")
        return nil
      }
      ArtworkLog.loaded(url, bytes: data.count)
      return image.preparingForDisplay() ?? image
    } catch {
      ArtworkLog.failed(url, reason: error.localizedDescription)
      return nil
    }
  }
}
#endif
