#if os(tvOS)
//
//  TVUIKitTileArtwork.swift
//  KinoPubUI
//
//  Solid-tint + SF Symbol artwork for tiles that have no photograph behind them:
//  genre / category rails, and the panel a media-item cell shows while its still
//  is in flight. `TVMediaItemContentConfiguration` only takes a `UIImage`, so a
//  "coloured placeholder" has to be a real drawn image rather than a background view.
//

import UIKit

public enum TVUIKitTileArtwork {
  /// 16:9, the shape `TVMediaItemContentConfiguration.wideCell()` renders.
  public static let wideSize = CGSize(width: 640, height: 360)

  /// Tile colours. Deliberately the system palette — these read as tinted artwork on a
  /// TV rather than as brand colour, and they are what the TVUIKit gallery shows.
  nonisolated(unsafe) public static let palette: [UIColor] = [
    .systemRed, .systemOrange, .systemYellow, .systemGreen,
    .systemTeal, .systemBlue, .systemIndigo, .systemPurple, .systemPink
  ]

  /// Same name → same colour, across launches. `String.hashValue` is seeded per
  /// process, so a genre would change colour every cold start if we used it.
  public static func tint(for name: String) -> UIColor {
    palette[Int(stableHash(name) % UInt64(palette.count))]
  }

  public static func wide(tint: UIColor, symbol: String?) -> UIImage {
    image(tint: tint, symbol: symbol, size: wideSize)
  }

  /// A flat tint with a centred glyph, cached per (tint, symbol, size) — a rail
  /// re-drawing this on every cell reuse is a renderer pass per scroll tick.
  public static func image(tint: UIColor, symbol: String?, size: CGSize) -> UIImage {
    let key = "\(tint.hashValue)-\(symbol ?? "-")-\(Int(size.width))x\(Int(size.height))" as NSString
    if let cached = cache.object(forKey: key) { return cached }

    let renderer = UIGraphicsImageRenderer(size: size)
    let drawn = renderer.image { context in
      tint.withAlphaComponent(0.85).setFill()
      context.fill(CGRect(origin: .zero, size: size))
      guard let symbol else { return }
      let config = UIImage.SymbolConfiguration(
        pointSize: min(size.width, size.height) * 0.32,
        weight: .semibold
      )
      guard let glyph = UIImage(systemName: symbol, withConfiguration: config)?
        .withTintColor(.white.withAlphaComponent(0.9), renderingMode: .alwaysOriginal)
      else { return }
      glyph.draw(at: CGPoint(x: (size.width - glyph.size.width) / 2,
                             y: (size.height - glyph.size.height) / 2))
    }
    cache.setObject(drawn, forKey: key)
    return drawn
  }

  /// Neutral panel for a still that has not arrived (or does not exist) — same shape as
  /// the artwork it stands in for, so the cell never resizes when the image lands.
  public static func placeholder(size: CGSize = wideSize) -> UIImage {
    image(tint: UIColor(white: 0.14, alpha: 1), symbol: nil, size: size)
  }

  /// `NSCache` is documented thread-safe, so the artwork helper does not need to be
  /// main-actor bound — `TVUIKitMediaItem` builds tinted tiles off the actor.
  nonisolated(unsafe) private static let cache = NSCache<NSString, UIImage>()

  /// FNV-1a over UTF-8 — stable across processes and platforms.
  private static func stableHash(_ value: String) -> UInt64 {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash = hash &* 0x100_0000_01b3
    }
    return hash
  }
}
#endif
