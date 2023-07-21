//
//  DownloadedFileInfo.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation

public struct DownloadedFileInfo: Codable {
  public let originalURL: URL
  public let localFilename: String
  public let downloadDate: Date
}

