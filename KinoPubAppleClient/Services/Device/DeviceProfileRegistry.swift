//
//  DeviceProfileRegistry.swift
//  KinoPubAppleClient
//
//  Remembers the device profile kino.pub already has, so `/v1/device/notify` and the
//  streaming settings go out when the device is *activated* — and after that only when
//  something they describe actually changed (renamed device, OS update, new app build,
//  restored onto different hardware, or a previous attempt that failed).
//
//  A cold launch that merely found a token in the Keychain writes nothing: re-pushing
//  the same profile every launch is what let a stale write silently clobber a profile
//  the user had just edited in Settings.
//

import Foundation

enum DeviceProfileRegistry {

  /// Bump when the fingerprint's shape changes, so every install re-registers once
  /// instead of trusting a value computed by older code.
  private static let schema = 1
  private static let storageKey = "com.kunst.kinopub.deviceProfileFingerprint"

  private static var defaults: UserDefaults { .standard }

  static func fingerprint(identity: DeviceIdentity.NotifyPayload, supportsHevc: Bool) -> String {
    [
      "v\(schema)",
      identity.title,
      identity.hardware,
      identity.software,
      supportsHevc ? "hevc" : "avc"
    ].joined(separator: "|")
  }

  static func isRegistered(_ fingerprint: String) -> Bool {
    defaults.string(forKey: storageKey) == fingerprint
  }

  static func markRegistered(_ fingerprint: String) {
    defaults.set(fingerprint, forKey: storageKey)
  }

  /// Signing out ends the tie between this install and an account's device record — the
  /// next sign-in has to register from scratch, possibly against a different account.
  static func reset() {
    defaults.removeObject(forKey: storageKey)
  }
}
