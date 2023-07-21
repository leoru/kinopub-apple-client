//
//  File.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation

public protocol DownloadedFilesDataReading {
  func readData() -> [DownloadedFileInfo]?
}

public protocol DownloadedFilesDataWriting {
  func writeData(_ files: [DownloadedFileInfo])
  func save(fileInfo: DownloadedFileInfo)
}

class DownloadedFilesDatabase: DownloadedFilesDataReading, DownloadedFilesDataWriting {
  private let fileSaver: FileSaving
  private let dataFileURL: URL
  
  public init(fileSaver: FileSaving) {
    self.fileSaver = fileSaver
    self.dataFileURL = fileSaver.getDocumentsDirectoryURL(forFilename: "downloadedFiles.plist")
  }
  
  func save(fileInfo: DownloadedFileInfo) {
    var currentData = readData() ?? []
    currentData.append(fileInfo)
    writeData(currentData)
  }
  
  func readData() -> [DownloadedFileInfo]? {
    guard let data = try? Data(contentsOf: dataFileURL),
          let decodedData = try? PropertyListDecoder().decode([DownloadedFileInfo].self, from: data) else {
      return nil
    }
    return decodedData
  }
  
  func writeData(_ files: [DownloadedFileInfo]) {
    if let data = try? PropertyListEncoder().encode(files) {
      try? data.write(to: dataFileURL)
    }
  }
}
