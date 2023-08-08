//
//  DownloadedFilesDatabase.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import KinoPubLogging
import OSLog

public protocol DownloadedFilesDataReading {
  associatedtype Meta: Codable & Equatable
  func readData() -> [DownloadedFileInfo<Meta>]?
}

public protocol DownloadedFilesDataWriting {
  associatedtype Meta: Codable & Equatable
  func writeData(_ files: [DownloadedFileInfo<Meta>])
  func save(fileInfo: DownloadedFileInfo<Meta>)
}

public class DownloadedFilesDatabase<Meta: Codable & Equatable>: DownloadedFilesDataReading, DownloadedFilesDataWriting {
  private let fileSaver: FileSaving
  private let dataFileURL: URL

  public init(fileSaver: FileSaving) {
    self.fileSaver = fileSaver
    self.dataFileURL = fileSaver.getDocumentsDirectoryURL(forFilename: "downloadedFiles.plist")
  }

  public func save(fileInfo: DownloadedFileInfo<Meta>) {
    var currentData = readData() ?? []
    currentData.append(fileInfo)
    writeData(currentData)
    Logger.kit.debug("[DOWNLOAD] save file info for: \(fileInfo.originalURL)")
  }

  public func readData() -> [DownloadedFileInfo<Meta>]? {
    guard let data = try? Data(contentsOf: dataFileURL),
          let decodedData = try? PropertyListDecoder().decode([DownloadedFileInfo<Meta>].self, from: data) else {
      return nil
    }
    return decodedData.sorted(by: { $0.downloadDate > $1.downloadDate })
  }

  public func writeData(_ files: [DownloadedFileInfo<Meta>]) {
    if let data = try? PropertyListEncoder().encode(files) {
      try? data.write(to: dataFileURL)
    }
  }
}
