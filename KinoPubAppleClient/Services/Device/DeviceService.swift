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
  /// Registers this device with kino.pub: a readable title/hardware/software triple via
  /// `POST /v1/device/notify`, plus the streaming profile (HEVC/4K/HDR + `mixedPlaylist`)
  /// this hardware can actually decode.
  ///
  /// Pass `activated: true` on the sign-in that just exchanged a device code — that is
  /// the point kino.pub expects a full profile. Every other call is a no-op unless the
  /// profile changed since the last successful registration.
  func syncDeviceProfile(activated: Bool) async
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

  func syncDeviceProfile(activated: Bool) async {}

  func listDevices() async throws -> [ManagedDevice] { [] }

  func removeDevice(id: Int) async throws {}
}
