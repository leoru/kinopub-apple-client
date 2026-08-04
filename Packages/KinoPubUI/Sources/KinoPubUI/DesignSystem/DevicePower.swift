//
//  DevicePower.swift
//  KinoPubUI
//

import Foundation

/// Hardware capability checks that change which rendering path we take.
public enum DevicePower {
#if os(tvOS)
  /// `AppleTV14,x` (A15, 3rd-gen 4K) is the first Apple TV with headroom for
  /// per-frame backdrop sampling over 4K video; earlier boxes opt into cheaper
  /// paths. False off tvOS hardware — the simulator reports the host machine
  /// string, so this never fires there.
  public static let isLowPowerAppleTV: Bool = {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machine = withUnsafeBytes(of: &systemInfo.machine) { raw in
      String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
    guard machine.hasPrefix("AppleTV") else { return false }
    let major = Int(machine.dropFirst("AppleTV".count).prefix(while: \.isNumber)) ?? 0
    return major > 0 && major < 14
  }()
#else
  public static let isLowPowerAppleTV = false
#endif
}
