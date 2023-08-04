//
//  File.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import XCTest
@testable import KinoPubKit

class DownloadedFilesDatabaseTests: XCTestCase {

  // MARK: - Test Variables

  var downloadedFilesDatabase: DownloadedFilesDatabase!
  var fileSaverMock: FileSaverMock1!

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()

    // Use FileSaverMock instead of the actual FileSaver
    fileSaverMock = FileSaverMock1()
    downloadedFilesDatabase = DownloadedFilesDatabase(fileSaver: fileSaverMock)
  }

  override func tearDown() {
    downloadedFilesDatabase = nil
    fileSaverMock = nil
    super.tearDown()
  }

  // MARK: - Test Methods

  func testSaveFile_Success() {
    // Arrange
    let originalURL = URL(string: "http://example.com/testfile.txt")!
    let localFilename = "testfile.txt"
    let downloadDate = Date()
    let fileInfo = DownloadedFileInfo(originalURL: originalURL, localFilename: localFilename, downloadDate: downloadDate)

    // Act
    downloadedFilesDatabase.save(fileInfo: fileInfo)

    // Assert
    XCTAssertTrue(fileSaverMock.didMoveItem)
  }

  func testSaveFile_ThrowsError() {
    // Arrange
    fileSaverMock.shouldThrowError = true
    let originalURL = URL(string: "http://example.com/testfile.txt")!
    let localFilename = "testfile.txt"
    let downloadDate = Date()
    let fileInfo = DownloadedFileInfo(originalURL: originalURL, localFilename: localFilename, downloadDate: downloadDate)

    // Act & Assert
    XCTAssertThrowsError(try downloadedFilesDatabase.save(fileInfo: fileInfo))
    XCTAssertTrue(fileSaverMock.didRemoveItem)
    XCTAssertFalse(fileSaverMock.didMoveItem)
  }

  func testReadData_Success() {
    // Arrange
    let originalURL1 = URL(string: "http://example.com/testfile1.txt")!
    let localFilename1 = "testfile1.txt"
    let downloadDate1 = Date()

    let originalURL2 = URL(string: "http://example.com/testfile2.txt")!
    let localFilename2 = "testfile2.txt"
    let downloadDate2 = Date()

    let fileInfo1 = DownloadedFileInfo(originalURL: originalURL1, localFilename: localFilename1, downloadDate: downloadDate1)
    let fileInfo2 = DownloadedFileInfo(originalURL: originalURL2, localFilename: localFilename2, downloadDate: downloadDate2)

    let testData = [fileInfo1, fileInfo2]
    let encodedData = try? PropertyListEncoder().encode(testData)
    fileSaverMock.dataToRead = encodedData

    // Act
    let retrievedData = downloadedFilesDatabase.readData()

    // Assert
    XCTAssertNotNil(retrievedData)
    XCTAssertEqual(retrievedData, testData)
  }

  func testReadData_DecodingError() {
    // Arrange
    fileSaverMock.dataToRead = "InvalidData".data(using: .utf8) // Invalid encoded data

    // Act
    let retrievedData = downloadedFilesDatabase.readData()

    // Assert
    XCTAssertNil(retrievedData)
  }
}

class FileSaverMock1: FileSaving {
  var shouldThrowError = false
  var didRemoveItem = false
  var didMoveItem = false
  var dataToRead: Data?

  func saveFile(from sourceURL: URL, to destinationURL: URL) throws {
    didRemoveItem = true
    didMoveItem = true

    if shouldThrowError {
      throw NSError(domain: "FileSaverMockErrorDomain", code: 123, userInfo: nil)
    }
  }

  func getDocumentsDirectoryURL(forFilename filename: String) -> URL {
    // Provide a mock URL for testing purposes
    return URL(string: "file:///path/to/documents/")!.appendingPathComponent(filename)
  }
}
