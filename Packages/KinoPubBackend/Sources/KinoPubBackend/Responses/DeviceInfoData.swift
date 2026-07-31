//
//  DeviceInfoData.swift
//

import Foundation

public struct DeviceInfoData: Decodable {

  public let device: DeviceInfo

  private enum CodingKeys: String, CodingKey {
    case device
  }

  public init(device: DeviceInfo) {
    self.device = device
  }

  public init(from decoder: Decoder) throws {
    if let container = try? decoder.container(keyedBy: CodingKeys.self),
       let device = try? container.decode(DeviceInfo.self, forKey: .device) {
      self.device = device
    } else {
      self.device = try DeviceInfo(from: decoder)
    }
  }

  public static func mock(device: DeviceInfo = .mock()) -> DeviceInfoData {
    DeviceInfoData(device: device)
  }
}
