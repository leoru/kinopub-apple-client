//
//  FileSaver.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation

public protocol FileSaving {
  func saveFile(from sourceURL: URL, to destinationURL: URL) throws
  func removeFile(at sourceURL: URL) throws
  func getDocumentsDirectoryURL(forFilename filename: String) -> URL
}

public class FileSaver: FileSaving {
  private let fileManager: FileManager

  public init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  public func saveFile(from sourceURL: URL, to destinationURL: URL) throws {
    try? fileManager.removeItem(at: destinationURL)
    try fileManager.moveItem(at: sourceURL, to: destinationURL)
  }
  
  public func removeFile(at sourceURL: URL) throws {
    try fileManager.removeItem(at: sourceURL)
  }

  public func getDocumentsDirectoryURL(forFilename filename: String) -> URL {
    let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    return documentsDirectoryURL.appendingPathComponent(filename)
  }
}
