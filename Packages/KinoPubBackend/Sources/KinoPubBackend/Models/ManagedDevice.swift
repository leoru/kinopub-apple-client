//
//  ManagedDevice.swift
//

import Foundation

/// A device on the account, from `GET /v1/device` → `{devices:[…]}`. Fields are tolerant: the live
/// list has null title/hardware on some rows.
public struct ManagedDevice: Decodable, Identifiable, Hashable {
  public let id: Int
  public let title: String?
  public let hardware: String?
  public let software: String?
  public let lastSeen: TimeInterval?
  public let isBrowser: Bool?

  private enum CodingKeys: String, CodingKey {
    case id, title, hardware, software
    case lastSeen = "last_seen"
    case isBrowser = "is_browser"
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if let i = try? c.decode(Int.self, forKey: .id) { id = i }
    else if let s = try? c.decode(String.self, forKey: .id), let p = Int(s) { id = p }
    else { id = 0 }
    title = try c.decodeIfPresent(String.self, forKey: .title)
    hardware = try c.decodeIfPresent(String.self, forKey: .hardware)
    software = try c.decodeIfPresent(String.self, forKey: .software)
    lastSeen = try c.decodeIfPresent(TimeInterval.self, forKey: .lastSeen)
    isBrowser = try c.decodeIfPresent(Bool.self, forKey: .isBrowser)
  }
}

public struct DevicesData: Decodable {
  public let devices: [ManagedDevice]
}
