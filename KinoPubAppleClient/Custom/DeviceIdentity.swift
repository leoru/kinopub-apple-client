//
//  DeviceIdentity.swift
//  KinoPubAppleClient
//
//  Builds the title / hardware / software triple for `POST /v1/device/notify`.
//  Middle ground between "unknown/unknown/unknown" and dumping raw utsname:
//
//    title:    "Alexander's MacBook" / Apple TV name
//    hardware: "MacBook Pro M1 Max, macOS 27"
//    software: "KinoPub, v0.56 (123)"
//
//  Capability badges (HLS4 / region / 4K / HEVC / HDR) come from device *settings*
//  via `DeviceService.syncCapabilities`, not from this notify payload.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import IOKit
#endif

enum DeviceIdentity {

  struct NotifyPayload {
    let title: String
    let hardware: String
    let software: String
  }

  static var current: NotifyPayload {
    NotifyPayload(title: deviceTitle, hardware: hardwareLine, software: softwareLine)
  }

  // MARK: - Fields

  private static var deviceTitle: String {
#if os(iOS) || os(tvOS)
    let name = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? defaultTitle : name
#elseif os(macOS)
    let name = (Host.current().localizedName ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? defaultTitle : name
#else
    return defaultTitle
#endif
  }

  private static var hardwareLine: String {
    "\(friendlyModel), \(shortOSVersion)"
  }

  private static var softwareLine: String {
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? defaultTitle
    let version = Bundle.main.appVersionLong
    let build = Bundle.main.appBuild
    if build != "⚠️", !build.isEmpty, build != version {
      return "\(name), v\(version) (\(build))"
    }
    return "\(name), v\(version)"
  }

  private static var defaultTitle: String { "KinoPub" }

  private static var shortOSVersion: String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
#if os(tvOS)
    return "tvOS \(v.majorVersion)"
#elseif os(iOS)
    return "iOS \(v.majorVersion)"
#elseif os(macOS)
    return "macOS \(v.majorVersion)"
#else
    return "Apple \(v.majorVersion)"
#endif
  }

  private static var friendlyModel: String {
    let id = machineIdentifier
    if let mapped = modelNames[id] { return mapped }
#if os(iOS) || os(tvOS)
    // "Apple TV" / "iPhone" is better than a bare unknown identifier.
    let generic = UIDevice.current.model.trimmingCharacters(in: .whitespacesAndNewlines)
    if !generic.isEmpty { return generic }
#endif
#if os(macOS)
    if let marketing = macModelFromIOKit(), !marketing.isEmpty {
      return marketing
    }
#endif
    return id.isEmpty ? "Apple" : id
  }

  /// utsname machine id — e.g. `MacBookPro18,2`, `AppleTV14,1`.
  private static var machineIdentifier: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifier = mirror.children.reduce(into: "") { result, element in
      guard let value = element.value as? Int8, value != 0 else { return }
      result.append(Character(UnicodeScalar(UInt8(value))))
    }
    return identifier
  }

#if os(macOS)
  /// Best-effort marketing name from IOKit (`model` property). Often still an
  /// identifier; `modelNames` covers the common Apple Silicon cases.
  private static func macModelFromIOKit() -> String? {
    let service = IOServiceGetMatchingService(
      kIOMainPortDefault,
      IOServiceMatching("IOPlatformExpertDevice")
    )
    guard service != 0 else { return nil }
    defer { IOObjectRelease(service) }
    guard let data = IORegistryEntryCreateCFProperty(
      service,
      "model" as CFString,
      kCFAllocatorDefault,
      0
    )?.takeRetainedValue() as? Data else { return nil }
    return String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
#endif

  // Compact map — unknown ids fall back to the raw identifier / UIDevice.model.
  // Expand as needed; this is only for the kino.pub devices list readability.
  private static let modelNames: [String: String] = [
    // Apple TV
    "AppleTV5,3": "Apple TV HD",
    "AppleTV6,2": "Apple TV 4K",
    "AppleTV11,1": "Apple TV 4K",
    "AppleTV14,1": "Apple TV 4K",
    // MacBook Pro (Apple Silicon)
    "MacBookPro17,1": "MacBook Pro M1",
    "MacBookPro18,1": "MacBook Pro M1 Pro",
    "MacBookPro18,2": "MacBook Pro M1 Max",
    "MacBookPro18,3": "MacBook Pro M1 Pro",
    "MacBookPro18,4": "MacBook Pro M1 Max",
    "Mac14,5": "MacBook Pro M2 Max",
    "Mac14,6": "MacBook Pro M2 Max",
    "Mac14,7": "MacBook Pro M2",
    "Mac14,9": "MacBook Pro M2 Pro",
    "Mac14,10": "MacBook Pro M2 Pro",
    "Mac15,3": "MacBook Pro M3",
    "Mac15,6": "MacBook Pro M3 Pro",
    "Mac15,7": "MacBook Pro M3 Pro",
    "Mac15,8": "MacBook Pro M3 Max",
    "Mac15,9": "MacBook Pro M3 Max",
    "Mac15,10": "MacBook Pro M3 Max",
    "Mac15,11": "MacBook Pro M3 Max",
    "Mac16,1": "MacBook Pro M4",
    "Mac16,5": "MacBook Pro M4 Pro",
    "Mac16,6": "MacBook Pro M4 Max",
    "Mac16,7": "MacBook Pro M4 Max",
    "Mac16,8": "MacBook Pro M4 Pro",
    // MacBook Air
    "MacBookAir10,1": "MacBook Air M1",
    "Mac14,2": "MacBook Air M2",
    "Mac14,15": "MacBook Air M2",
    "Mac15,12": "MacBook Air M3",
    "Mac15,13": "MacBook Air M3",
    "Mac16,12": "MacBook Air M4",
    "Mac16,13": "MacBook Air M4",
    // Mac mini / Studio / iMac
    "Macmini9,1": "Mac mini M1",
    "Mac14,3": "Mac mini M2",
    "Mac14,12": "Mac mini M2 Pro",
    "Mac16,10": "Mac mini M4",
    "Mac16,11": "Mac mini M4 Pro",
    "Mac13,1": "Mac Studio M1 Max",
    "Mac13,2": "Mac Studio M1 Ultra",
    "Mac14,13": "Mac Studio M2 Max",
    "Mac14,14": "Mac Studio M2 Ultra",
    "iMac21,1": "iMac M1",
    "iMac21,2": "iMac M1",
    "Mac15,4": "iMac M3",
    "Mac15,5": "iMac M3",
  ]
}
