//
//  DeviceCapabilities.swift
//  KinoPubAppleClient
//
//  Detects whether this device can DECODE HEVC (incl. 10-bit / HDR10), so we advertise
//  HEVC/4K/HDR to kino.pub only where the stream will actually play. Ported from
//  dungeon-master-xx/kinopub-apple-client.
//

import Foundation
import VideoToolbox
import CoreMedia

enum DeviceCapabilities {

  /// Whether this hardware can decode HEVC (and therefore the HDR10 master). True on
  /// A10+ real devices. False on the Simulator and on pre-HEVC hardware, where
  /// advertising HEVC would yield an undecodable stream.
  static var supportsHEVC: Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
    #endif
  }
}
