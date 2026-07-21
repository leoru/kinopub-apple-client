//
//  FileSaverMock.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
@testable import KinoPubKit

/// Records what it was asked to do, and hands out paths inside a throwaway
/// directory so `DownloadedFilesDatabase` — which reads and writes the plist
/// itself rather than going through `FileSaving` — has somewhere real to work.
class FileSaverMock: FileSaving {

  var shouldThrowError = false
  var didSaveFileCalled = false
  var savedFileSourceURL: URL?
  var savedFileDestinationURL: URL?
  var didRemoveFileCalled = false
  var removedFileURL: URL?

  let directoryURL: URL

  init() {
    directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("KinoPubKitTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: directoryURL)
  }

  func saveFile(from sourceURL: URL, to destinationURL: URL) throws {
    if shouldThrowError {
      throw NSError(domain: "FileSaverMockErrorDomain", code: 123, userInfo: nil)
    }

    didSaveFileCalled = true
    savedFileSourceURL = sourceURL
    savedFileDestinationURL = destinationURL
  }

  func removeFile(at sourceURL: URL) throws {
    if shouldThrowError {
      throw NSError(domain: "FileSaverMockErrorDomain", code: 123, userInfo: nil)
    }

    didRemoveFileCalled = true
    removedFileURL = sourceURL
  }

  func getDocumentsDirectoryURL(forFilename filename: String) -> URL {
    directoryURL.appendingPathComponent(filename)
  }
}

/// Stand-in for the app's `DownloadMeta`, which lives in the app target.
struct TestMeta: Codable, Equatable {
  let id: Int
  let title: String
}
