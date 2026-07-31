//
//  StreamQuality.swift
//  KinoPubAppleClient
//
//  User-selectable cap for streaming quality. kino.pub's `hls4`/`hls2` URLs are a single
//  adaptive HLS master (all renditions in one playlist regardless of which `files[]` entry
//  the URL came from), so quality is not chosen by swapping URLs — it's enforced by capping
//  the AVPlayerItem's `preferredMaximumResolution`. `.auto` leaves AVPlayer's ABR untouched.
//

import Foundation
import CoreGraphics

enum StreamQuality: String, CaseIterable, Identifiable {
  case auto
  case uhd2160
  case fhd1080
  case hd720
  case sd480

  var id: String { rawValue }

  /// UserDefaults / @AppStorage key shared between the settings screen and the player.
  static let userDefaultsKey = "preferredStreamQuality"

  /// The cap applied to `AVPlayerItem.preferredMaximumResolution`. `nil` means "no cap" (Auto).
  /// kino.pub's anamorphic content (e.g. 1920x800) stays under the nominal 16:9 height, so the
  /// width is the effective gate and these nominal sizes select the intended rung.
  var maxResolution: CGSize? {
    switch self {
    case .auto: return nil
    case .uhd2160: return CGSize(width: 3840, height: 2160)
    case .fhd1080: return CGSize(width: 1920, height: 1080)
    case .hd720: return CGSize(width: 1280, height: 720)
    case .sd480: return CGSize(width: 854, height: 480)
    }
  }

  /// Height in points for HLS download bitrate capping (`HLSAssetDownloadManager`).
  var maxHeight: Int? {
    guard let maxResolution else { return nil }
    return Int(maxResolution.height)
  }

  var title: String {
    switch self {
    case .auto: return "Auto".localized
    case .uhd2160: return "2160p (4K)"
    case .fhd1080: return "1080p"
    case .hd720: return "720p"
    case .sd480: return "480p"
    }
  }

  /// The preference currently stored by the settings screen, for non-View consumers (PlayerManager).
  static var current: StreamQuality {
    guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
          let value = StreamQuality(rawValue: raw) else {
      return .auto
    }
    return value
  }
}
