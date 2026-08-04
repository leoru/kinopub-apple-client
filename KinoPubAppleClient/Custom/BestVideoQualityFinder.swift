//
//  BestVideoQualityFinder.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import SystemConfiguration
import Reachability
import KinoPubBackend

struct BestVideoQualityFinder {

#if canImport(UIKit) && !os(macOS)
  /// Vertical display capability in pixels, matched against `FileInfo.resolution` (e.g. 1080 from "1080p").
  /// Uses `nativeBounds` so Apple TV 4K reports ~2160 rather than the 1080pt UI buffer.
  private static var deviceCapabilitySize: CGFloat {
    guard let screen = preferredScreen() else { return 1080 }
    let pixels = screen.nativeBounds.size
    return min(pixels.width, pixels.height)
  }

  private static func preferredScreen() -> UIScreen? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    if let active = scenes.first(where: { $0.activationState == .foregroundActive }) {
      return active.screen
    }
    return scenes
      .max {
        min($0.screen.nativeBounds.width, $0.screen.nativeBounds.height)
          < min($1.screen.nativeBounds.width, $1.screen.nativeBounds.height)
      }?
      .screen
  }
#endif

  private static func currentNetworkStatus() -> Reachability.Connection {
    guard let reachability = try? Reachability() else { return .unavailable }
    return reachability.connection
  }

  private static func isConnectionGood() -> Bool {
    currentNetworkStatus() == .wifi
  }

  static func findBestURL(for files: [FileInfo]) -> String {
    var bestURL: String = files.last?.url.hls4 ?? ""
    var closestResolutionDifference = Int.max

#if os(macOS)
    bestURL = files.first?.url.hls4 ?? ""
#endif

#if canImport(UIKit) && !os(macOS)
    guard isConnectionGood() else {
      return bestURL
    }

    for fileInfo in files {
      let resolutionDifference = abs(fileInfo.resolution - Int(deviceCapabilitySize))

      if fileInfo.resolution <= Int(deviceCapabilitySize) && resolutionDifference < closestResolutionDifference {
        bestURL = fileInfo.url.hls4
        closestResolutionDifference = resolutionDifference
      }
    }
#endif

    return bestURL
  }
}
