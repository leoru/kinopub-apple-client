//
//  FileInfo.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct FileInfo: Codable, Hashable {
  public let codec: String
  public let w: Int
  public let h: Int
  public let quality: String
  public let qualityID: Int
  public let url: URLInfo

  private enum CodingKeys: String, CodingKey {
    case codec = "codec"
    case w = "w"
    case h = "h"
    case quality = "quality"
    case qualityID = "quality_id"
    case url = "url"
  }
}
