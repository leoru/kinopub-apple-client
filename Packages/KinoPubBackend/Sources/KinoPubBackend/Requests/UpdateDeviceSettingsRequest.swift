//
//  UpdateDeviceSettingsRequest.swift
//

import Foundation

/// Updates the device streaming profile — `POST /v1/device/{id}/settings`.
///
/// Settings must go in the form-urlencoded **body** (`forceSendAsGetParams = false`).
/// Query params silently no-op and the profile appears to "reset" after saving.
public struct UpdateDeviceSettingsRequest: Endpoint {

  public var id: Int
  public var settings: DeviceSettings

  public init(id: Int, settings: DeviceSettings) {
    self.id = id
    self.settings = settings
  }

  public var path: String { "/v1/device/\(id)/settings" }
  public var method: String { "POST" }

  public var parameters: [String: Any]? {
    [
      "streamingType": settings.streamingType,
      "serverLocation": settings.serverLocation,
      "support4k": settings.support4k ? 1 : 0,
      "supportHevc": settings.supportHevc ? 1 : 0,
      "supportHdr": settings.supportHdr ? 1 : 0,
      "mixedPlaylist": settings.mixedPlaylist ? 1 : 0
    ]
  }

  public var headers: [String: String]? { nil }
  public var forceSendAsGetParams: Bool { false }
}
