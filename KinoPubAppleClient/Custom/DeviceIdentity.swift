//
//  DeviceIdentity.swift
//  KinoPubAppleClient
//
//  Builds the title / hardware / software triple for `POST /v1/device/notify`.
//
//    title:    "Sasha's MacBook Pro" / "Apple TV" — whatever the *system* calls it
//    hardware: "Mac (MacBookPro18,2, Apple M1 Max)" / "iPhone (iPhone17,1)"
//    software: "macOS 26.1, KinoPub v0.56 (123)"
//
//  Everything here comes from the OS at runtime — no table of model identifiers to keep
//  up to date, because the device list is a zoo and an unknown identifier must still
//  produce a readable row. `hardware` keeps the raw identifier in parentheses so a new
//  Apple TV or Mac is still exactly identifiable the day it ships.
//
//  Capability badges (HLS4 / region / 4K / HEVC / HDR) come from device *settings*
//  via `DeviceService`, not from this notify payload.
//

import Foundation
#if os(watchOS)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#endif

enum DeviceIdentity {

  struct NotifyPayload: Equatable {
    let title: String
    let hardware: String
    let software: String
  }

  static var current: NotifyPayload {
    NotifyPayload(title: deviceName, hardware: hardwareLine, software: softwareLine)
  }

  // MARK: - Fields

  /// The name the system gives this device — the one string that must read the same
  /// wherever the app shows it, so nothing else may invent its own.
  ///
  /// iOS/iPadOS 16+ answer with the model name ("iPhone") unless the app carries the
  /// user-assigned-device-name entitlement; that is still the system's name for it and
  /// beats anything we could synthesize.
  static var deviceName: String {
    let name: String
#if os(watchOS)
    name = WKInterfaceDevice.current().name
#elseif canImport(UIKit)
    name = UIDevice.current.name
#elseif os(macOS)
    name = Host.current().localizedName ?? ""
#else
    name = ""
#endif
    let cleaned = sanitized(name)
    return cleaned.isEmpty ? modelFamily : cleaned
  }

  /// `Host.current().localizedName` returns a localized name wrapped in bidi isolates
  /// (U+2068/U+2069) — invisible to a whitespace trim, stray marks in kino.pub's list.
  private static func sanitized(_ raw: String) -> String {
    let scalars = raw.unicodeScalars.filter { $0.properties.generalCategory != .format }
    return String(String.UnicodeScalarView(scalars))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The system's own word for this class of device: "iPhone", "iPad", "Apple TV",
  /// "Apple Watch", "Apple Vision Pro", "Mac".
  static var modelFamily: String {
    let model: String
#if os(watchOS)
    model = WKInterfaceDevice.current().model
#elseif canImport(UIKit)
    model = UIDevice.current.model
#elseif os(macOS)
    model = "Mac"
#else
    model = ""
#endif
    let cleaned = sanitized(model)
    return cleaned.isEmpty ? "Apple" : cleaned
  }

  /// "iOS" / "iPadOS" / "tvOS" / "watchOS" / "visionOS" / "macOS", straight from the OS.
  static var systemName: String {
#if os(watchOS)
    return WKInterfaceDevice.current().systemName
#elseif canImport(UIKit)
    return UIDevice.current.systemName
#elseif os(macOS)
    // AppKit has no equivalent of `UIDevice.systemName`, and every other spelling
    // ("Mac OS X", "Version 26.1") is worse than the name Apple ships.
    return "macOS"
#else
    return "Apple"
#endif
  }

  static var systemVersion: String {
#if os(watchOS)
    return WKInterfaceDevice.current().systemVersion
#elseif canImport(UIKit)
    return UIDevice.current.systemVersion
#else
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let short = "\(version.majorVersion).\(version.minorVersion)"
    return version.patchVersion == 0 ? short : "\(short).\(version.patchVersion)"
#endif
  }

  /// `MacBookPro18,2`, `AppleTV14,1`, `iPhone17,1`. Empty only if every source fails.
  static var machineIdentifier: String {
    // The Simulator's `uname` reports the host Mac's architecture ("arm64"); the device
    // being simulated is in the environment instead.
    if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
       !simulated.isEmpty {
      return simulated
    }
#if os(macOS)
    // Same reason: on macOS `uname` is the architecture, and the model lives in sysctl.
    return sysctl("hw.model") ?? ""
#else
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafeBytes(of: &systemInfo.machine) { raw in
      String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
#endif
  }

  // MARK: - Lines

  private static var hardwareLine: String {
    var details: [String?] = [machineIdentifier]
#if os(macOS)
    // macOS exposes no marketing name anywhere, but it does expose the chip — which is
    // what tells two identical-looking "Mac16,6" rows apart.
    details.append(sysctl("machdep.cpu.brand_string"))
#endif
    let detail = details.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    return detail.isEmpty ? modelFamily : "\(modelFamily) (\(detail))"
  }

  /// kino.pub's own docs put the OS in `software` (`'software': 'iOS/8.3'`), so the app
  /// build rides along behind it rather than pushing it into `hardware`.
  private static var softwareLine: String {
    // `INFOPLIST_KEY_CFBundleDisplayName` carries the shipping name ("Kinopub Soda"), so the
    // literal is only a last resort — keep it in step with the build setting.
    let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "Kinopub Soda"
    let version = Bundle.main.appVersionLong
    let build = Bundle.main.appBuild
    let app: String
    if build != "⚠️", !build.isEmpty, build != version {
      app = "\(name) v\(version) (\(build))"
    } else {
      app = "\(name) v\(version)"
    }
    return "\(systemName) \(systemVersion), \(app)"
  }

#if os(macOS)
  private static func sysctl(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
    let value = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
  }
#endif
}
