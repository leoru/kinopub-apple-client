
//
//  BestVideoQualityFinder.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.08.2023.
//

import Foundation
#if os(iOS)
import UIKit
#endif
import SystemConfiguration
import Reachability
import KinoPubBackend

struct BestVideoQualityFinder {
  
  #if os(iOS)
  private static var deviceCapabilitySize: CGFloat {
    UIApplication.shared.statusBarOrientation.isLandscape ? UIScreen.main.bounds.width : UIScreen.main.bounds.height
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
    
    #if os(iOS)
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
