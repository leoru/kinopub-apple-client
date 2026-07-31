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
  /// `POST /v1/device/notify` with a readable title/hardware/software triple.
  func registerDeviceIdentity() async
  /// Advertises this hardware's real capabilities (HEVC/4K/HDR + mixedPlaylist) so
  /// kino.pub serves streams the native player can open.
  func syncCapabilities() async
  /// Account device list — service ready; Settings UI is DESIGN TBD.
  func listDevices() async throws -> [ManagedDevice]
  func removeDevice(id: Int) async throws
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

  func registerDeviceIdentity() async {}

  func syncCapabilities() async {}

  func listDevices() async throws -> [ManagedDevice] { [] }

  func removeDevice(id: Int) async throws {}
}
