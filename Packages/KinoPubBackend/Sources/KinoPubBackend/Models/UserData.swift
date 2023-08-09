//
//  UserData.swift
//
//
//  Created by Kirill Kunst on 9.08.2023.
//

import Foundation

public struct UserData: Codable {
  
  public struct Subscription: Codable {
    public let active: Bool
    public let endTime: TimeInterval
    public let days: Double
    
    private enum CodingKeys: String, CodingKey {
      case active, days
      case endTime = "end_time"
    }
  }
  
  public struct Profile: Codable {
    public let name: String?
    public let avatar: String?
  }
  
  public struct Settings: Codable {
    public let showErotic: Bool
    public let showUncertain: Bool
    
    private enum CodingKeys: String, CodingKey {
      case showErotic = "show_erotic"
      case showUncertain = "show_uncertain"
    }
  }
  
  public let username: String
  public let registrationDate: TimeInterval
  public let settings: Settings
  public let subscription: Subscription
  public let profile: Profile
  public let skeleton: Bool?
  
  private enum CodingKeys: String, CodingKey {
    case username, subscription, profile, settings, skeleton
    case registrationDate = "reg_date"
  }
}

public extension UserData {
  var registrationDateFormatted: String {
    Date(timeIntervalSince1970: self.registrationDate).formatted()
  }
}

public extension UserData {
  static func mock() -> UserData {
    UserData(username: "Test User",
             registrationDate: 0,
             settings: Settings(showErotic: true, showUncertain: true),
             subscription: Subscription(active: true, endTime: 3333333, days: 20.5),
             profile: Profile(name: "Test User Full", avatar: ""),
             skeleton: true)
  }
}
