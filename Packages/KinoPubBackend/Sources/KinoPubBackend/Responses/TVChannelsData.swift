//
//  TVChannelsData.swift
//
//
//  Response wrapper for GET /v1/tv.
//

import Foundation

public struct TVChannelsData: Decodable {
  public let channels: [TVChannel]

  public init(channels: [TVChannel]) {
    self.channels = channels
  }

  private enum CodingKeys: String, CodingKey {
    case channels
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    channels = (try? container.decode([TVChannel].self, forKey: .channels)) ?? []
  }

  public static func mock(_ channels: [TVChannel] = []) -> TVChannelsData {
    TVChannelsData(channels: channels)
  }
}
