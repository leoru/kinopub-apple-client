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
  private static var deviceCapabilitySize: CGFloat {
#if os(tvOS)
    return max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
#else
    UIApplication.shared.statusBarOrientation.isLandscape
      ? UIScreen.main.bounds.width
      : UIScreen.main.bounds.height
#endif
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
