//
//  FileManagerMock.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation

class FileManagerMock: FileManager {
  var shouldThrowError = false

  /// These record *attempts*: the flag is set before the throw, so a true value
  /// means the call was made, not that it succeeded.
  var didAttemptRemoveItem = false
  var didAttemptMoveItem = false

  override func removeItem(at URL: URL) throws {
    didAttemptRemoveItem = true
    if shouldThrowError {
      throw NSError(domain: "FileManagerMockErrorDomain", code: 123, userInfo: nil)
    }
  }

  override func moveItem(at srcURL: URL, to dstURL: URL) throws {
    didAttemptMoveItem = true
    if shouldThrowError {
      throw NSError(domain: "FileManagerMockErrorDomain", code: 456, userInfo: nil)
    }
  }
}
