//
//  FileManagerMock.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation

class FileManagerMock: FileManager {
  var shouldThrowError = false
  var didRemoveItem = false
  var didMoveItem = false

  override func removeItem(at URL: URL) throws {
    didRemoveItem = true
    if shouldThrowError {
      throw NSError(domain: "FileManagerMockErrorDomain", code: 123, userInfo: nil)
    }
  }

  override func moveItem(at srcURL: URL, to dstURL: URL) throws {
    didMoveItem = true
    if shouldThrowError {
      throw NSError(domain: "FileManagerMockErrorDomain", code: 456, userInfo: nil)
    }
  }
}
