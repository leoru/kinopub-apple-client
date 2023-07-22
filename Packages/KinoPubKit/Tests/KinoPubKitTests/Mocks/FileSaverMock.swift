//
//  FileSaverMock.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
@testable import KinoPubKit

class FileSaverMock: FileSaving {
  
  var shouldThrowError = false
  var didSaveFileCalled = false
  var savedFileSourceURL: URL?
  var savedFileDestinationURL: URL?
  
  func saveFile(from sourceURL: URL, to destinationURL: URL) throws {
    didSaveFileCalled = true
    savedFileSourceURL = sourceURL
    savedFileDestinationURL = destinationURL
    
    if shouldThrowError {
      throw NSError(domain: "FileSaverMockErrorDomain", code: 123, userInfo: nil)
    }
  }
  
  func getDocumentsDirectoryURL(forFilename filename: String) -> URL {
    // Provide a mock URL for testing purposes
    return URL(string: "file:///path/to/documents/")!.appendingPathComponent(filename)
  }
}
