//
//  BestVideoQualityFinder.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
import UIKit
import SystemConfiguration
import Reachability
import KinoPubBackend

struct BestVideoQualityFinder {
  
  private static let deviceCapabilitySize = UIApplication.shared.statusBarOrientation.isLandscape ? UIScreen.main.bounds.width : UIScreen.main.bounds.height
  
  private static func currentNetworkStatus() -> Reachability.Connection {
    guard let reachability = try? Reachability() else { return .unavailable }
    return reachability.connection
  }
  
  private static func isConnectionGood() -> Bool {
    let connectionType = currentNetworkStatus()
    // Assuming that a Wi-Fi connection is good and cellular may not be as good
    // You can add more specific checks here based on your requirements
    return connectionType == .wifi
  }
  
  
  static func findBestURL(for files: [FileInfo]) -> String {
    var bestURL: String = files.last?.url.hls4 ?? ""
    var closestResolutionDifference = Int.max
    
    if !isConnectionGood() {
      return bestURL
    }
    
    for fileInfo in files {
      let resolution = fileInfo.resolution
      let resolutionDifference = abs(resolution - Int(deviceCapabilitySize))
      
      // Assuming Wi-Fi connection is good, choosing the closest resolution to the device's capability
      if resolution <= Int(deviceCapabilitySize) && resolutionDifference < closestResolutionDifference {
        bestURL = fileInfo.url.hls4
        closestResolutionDifference = resolutionDifference
      }
    }
    
    return bestURL
  }
  
}
