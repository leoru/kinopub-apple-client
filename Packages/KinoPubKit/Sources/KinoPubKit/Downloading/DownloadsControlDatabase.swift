//
//  DownloadsControlDatabase.swift
//
//
//  Created by Claude on 24.06.2026.
//

import Foundation
import KinoPubLogging
import OSLog

public protocol DownloadsControlDataReading {
  associatedtype Meta: Codable & Equatable
  func readData() -> [DownloadControlInfo<Meta>]?
}

public protocol DownloadsControlDataWriting {
  associatedtype Meta: Codable & Equatable
  func writeData(_ downloads: [DownloadControlInfo<Meta>])
  func save(controlInfo: DownloadControlInfo<Meta>)
  func remove(url: URL)
}

/// Persists in-progress / paused downloads (their resume data, progress and metadata) so they can be
/// restored after the app is relaunched. Uses the same `FileSaver`/plist approach as `DownloadedFilesDatabase`.
public class DownloadsControlDatabase<Meta: Codable & Equatable>: DownloadsControlDataReading, DownloadsControlDataWriting {
  private let fileSaver: FileSaving
  private let dataFileURL: URL

  public init(fileSaver: FileSaving) {
    self.fileSaver = fileSaver
    self.dataFileURL = fileSaver.getDocumentsDirectoryURL(forFilename: "activeDownloads.plist")
  }

  /// Saves (or replaces) the control info for a single download, keyed by its original URL.
  public func save(controlInfo: DownloadControlInfo<Meta>) {
    var currentData = readData() ?? []
    currentData.removeAll(where: { $0.originalURL == controlInfo.originalURL })
    currentData.append(controlInfo)
    writeData(currentData)
    Logger.kit.debug("[DOWNLOAD] save control info for: \(controlInfo.originalURL)")
  }

  public func readData() -> [DownloadControlInfo<Meta>]? {
    guard let data = try? Data(contentsOf: dataFileURL),
          let decodedData = try? PropertyListDecoder().decode([DownloadControlInfo<Meta>].self, from: data) else {
      return nil
    }
    return decodedData
  }

  public func writeData(_ downloads: [DownloadControlInfo<Meta>]) {
    if let data = try? PropertyListEncoder().encode(downloads) {
      try? data.write(to: dataFileURL)
    }
  }

  /// Removes the persisted entry for a download (e.g. when it completes or is cancelled).
  public func remove(url: URL) {
    var currentData = readData() ?? []
    currentData.removeAll(where: { $0.originalURL == url })
    writeData(currentData)
    Logger.kit.debug("[DOWNLOAD] control info removed: \(url)")
  }
}
