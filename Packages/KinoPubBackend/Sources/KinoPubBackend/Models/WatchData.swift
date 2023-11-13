//
//  WatchData.swift
//
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation

public struct WatchData: Codable, Hashable {
  
  public struct Season: Codable, Hashable {
    public var id: Int
    public var number: Int
    public var status: Int
    public var episodes: [WatchDataItem]
  }
  
  public struct WatchDataItem: Codable, Hashable {
    public var id: Int
    public var number: Int
    public var title: String
    public var time: TimeInterval
    public var status: Int
  }
  
  public var seasons: [Season]?
  public var videos: [WatchDataItem]?
  
  public init() {}
  
}
