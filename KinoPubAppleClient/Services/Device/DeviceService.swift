//
//  DeviceService.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

protocol DeviceService {
  func fetchCurrentDevice() async throws -> DeviceInfo
  func fetchSettings(deviceId: Int) async throws -> DeviceSettings
  func updateSettings(deviceId: Int, settings: DeviceSettings) async throws
  /// Advertises this hardware's real capabilities (HEVC/4K/HDR + mixedPlaylist) so
  /// kino.pub serves streams the native player can open.
  func syncCapabilities() async
}

protocol DeviceServiceProvider {
  var deviceService: DeviceService { get set }
}

struct DeviceServiceMock: DeviceService {

  func fetchCurrentDevice() async throws -> DeviceInfo {
    DeviceInfo.mock()
  }

  func fetchSettings(deviceId: Int) async throws -> DeviceSettings {
    DeviceSettings.mock()
  }

  func updateSettings(deviceId: Int, settings: DeviceSettings) async throws {}

  func syncCapabilities() async {}
}
