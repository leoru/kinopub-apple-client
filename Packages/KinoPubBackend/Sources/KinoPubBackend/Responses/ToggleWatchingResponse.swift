//
//  ToggleWatchingResponse.swift
//

import Foundation

/// `/v1/watching/toggle` returns the new watched flag for the targeted video.
public struct ToggleWatchingResponse: Codable {
  public let status: Int
  /// 1 when marked watched, 0 when marked unwatched. Absent on older payloads.
  public let watched: Int?
}
