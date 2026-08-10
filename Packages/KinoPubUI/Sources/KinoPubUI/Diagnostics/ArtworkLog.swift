#if os(tvOS)
//
//  ArtworkLog.swift
//  KinoPubUI
//
//  Tracing for the TVUIKit artwork path. It exists because of a question that was
//  unanswerable from the screen: when a rail shows monograms instead of faces, is the
//  request failing, or was it never made? Those two look identical and have opposite
//  fixes — one is the photo source, the other is the code that decides there is no
//  photo to fetch. `requested` / `skipped` separate them on the first frame.
//
//  Read it with either:
//    Console.app → filter subsystem `artwork`
//    xcrun simctl spawn booted log stream --predicate 'category == "artwork"'
//

import OSLog
import Foundation

public enum ArtworkLog {

  /// Off in release builds; the instrumentation compiles away with it.
  public static var isEnabled: Bool = {
#if DEBUG
    true
#else
    false
#endif
  }()

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "KinoPub",
    category: "artwork"
  )

  /// A cell asked for a URL we did not already have decoded.
  public static func requested(_ url: URL, by owner: String) {
    guard isEnabled else { return }
    logger.debug("↓ GET  \(owner, privacy: .public) · \(url.lastPathComponent, privacy: .public)")
  }

  /// A cell had nothing to ask for. This is the line that says "no photo was known",
  /// as opposed to "the photo failed" — the distinction the whole log exists for.
  public static func skipped(by owner: String, reason: String) {
    guard isEnabled else { return }
    logger.info("· SKIP \(owner, privacy: .public) · \(reason, privacy: .public)")
  }

  /// Served from the decoded-image cache without touching the network or a decode.
  public static func servedFromMemory(_ url: URL, by owner: String) {
    guard isEnabled else { return }
    logger.debug("✓ MEM  \(owner, privacy: .public) · \(url.lastPathComponent, privacy: .public)")
  }

  public static func loaded(_ url: URL, bytes: Int) {
    guard isEnabled else { return }
    logger.debug("✓ LOAD \(url.lastPathComponent, privacy: .public) · \(bytes / 1024, privacy: .public) KB")
  }

  public static func failed(_ url: URL, reason: String) {
    guard isEnabled else { return }
    logger.error("✖ FAIL \(url.absoluteString, privacy: .public) · \(reason, privacy: .public)")
  }
}
#endif
