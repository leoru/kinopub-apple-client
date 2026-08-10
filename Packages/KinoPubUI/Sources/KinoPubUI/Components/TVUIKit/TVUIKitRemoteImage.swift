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
//  Decoding happens off the main thread and **down to the tile's size**. That second
//  part is what makes the cache actually hold a screen: a 1 MB wide still decodes to
//  ~8 MB at full resolution, so a 64 MB budget held roughly eight of them and evicted
//  everything else — which is why tiles kept going blank a short scroll away even with a
//  cache in front of `URLCache`. At tile size the same budget holds hundreds.
//

import UIKit

public enum TVUIKitRemoteImage {

  /// Decoded images, keyed by URL. `NSCache` is thread-safe and evicts itself under
  /// memory pressure, which is the behaviour we want on an Apple TV HD.
  private static let memory: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.name = "TVUIKitRemoteImage"
    cache.totalCostLimit = 64 * 1024 * 1024
    return cache
  }()

  /// Already-decoded art for this URL at this tile size, or nil. Synchronous on purpose:
  /// a cell calls this while configuring so a recycled tile never paints a placeholder.
  public static func cached(url: URL?, size: CGSize = .zero) -> UIImage? {
    guard let url else { return nil }
    return memory.object(forKey: key(url, size))
  }

  /// - Parameter size: the tile this art is going into, in points. Artwork is decoded
  ///   down to it — passing `.zero` keeps full resolution and should be rare.
  public static func load(url: URL?, size: CGSize = .zero) async -> UIImage? {
    guard let url else { return nil }
    if let hit = cached(url: url, size: size) { return hit }
    return await ArtworkFetcher.shared.image(for: url, size: size)
  }

  /// Warm the cache for art that is about to scroll into view. Fire-and-forget: the
  /// results land in `memory`, and the cell that eventually needs one finds it there.
  public static func prefetch(_ urls: [URL?], size: CGSize = .zero) {
    for case let url? in urls where cached(url: url, size: size) == nil {
      Task.detached(priority: .utility) { _ = await load(url: url, size: size) }
    }
  }

  /// Size is part of the key: the same still is a different decode in a rail and in a
  /// grid, and handing one out for the other is either blurry or wasteful.
  fileprivate static func key(_ url: URL, _ size: CGSize) -> NSString {
    size == .zero
      ? url.absoluteString as NSString
      : "\(url.absoluteString)|\(Int(size.width))x\(Int(size.height))" as NSString
  }

  fileprivate static func store(_ image: UIImage, for url: URL, size: CGSize) {
    let pixels = image.size.width * image.scale * image.size.height * image.scale
    memory.setObject(image, forKey: key(url, size), cost: Int(pixels) * 4)
  }
}

/// Coalesces concurrent requests for the same URL. Without it, a rail that configures
/// eight cells for the same missing poster fires eight identical downloads.
private actor ArtworkFetcher {
  static let shared = ArtworkFetcher()

  private var inFlight: [String: Task<UIImage?, Never>] = [:]

  func image(for url: URL, size: CGSize) async -> UIImage? {
    let key = TVUIKitRemoteImage.key(url, size) as String
    if let existing = inFlight[key] { return await existing.value }
    let task = Task<UIImage?, Never> { await Self.fetch(url, size: size) }
    inFlight[key] = task
    let image = await task.value
    inFlight[key] = nil
    if let image { TVUIKitRemoteImage.store(image, for: url, size: size) }
    return image
  }

  private static func fetch(_ url: URL, size: CGSize) async -> UIImage? {
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
      guard size != .zero else { return image.preparingForDisplay() ?? image }
      // Decoded straight to the tile it is going into. `preparingThumbnail` does the
      // downsample and the decode in one off-main step.
      let scale = UITraitCollection.current.displayScale
      let pixels = CGSize(width: size.width * scale, height: size.height * scale)
      return image.preparingThumbnail(of: pixels) ?? image.preparingForDisplay() ?? image
    } catch {
      ArtworkLog.failed(url, reason: error.localizedDescription)
      return nil
    }
  }
}
#endif
