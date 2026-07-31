//
//  DownloadedFilesDatabaseTests.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import XCTest
@testable import KinoPubKit

class DownloadedFilesDatabaseTests: XCTestCase {

  // MARK: - Test Variables

  var database: DownloadedFilesDatabase<TestMeta>!
  var fileSaverMock: FileSaverMock!

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()

    fileSaverMock = FileSaverMock()
    database = DownloadedFilesDatabase<TestMeta>(fileSaver: fileSaverMock)
  }

  override func tearDown() {
    database = nil
    fileSaverMock = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func makeFileInfo(_ name: String, downloadedAt date: Date = Date()) -> DownloadedFileInfo<TestMeta> {
    DownloadedFileInfo(originalURL: URL(string: "http://example.com/\(name)")!,
                       localFilename: name,
                       downloadDate: date,
                       metadata: TestMeta(id: name.hashValue, title: name))
  }

  // MARK: - Test Methods

  func testReadDataReturnsNilWhenNothingSaved() {
    XCTAssertNil(database.readData())
  }

  func testSaveThenReadRoundTrips() {
    let fileInfo = makeFileInfo("testfile.txt")

    database.save(fileInfo: fileInfo)

    XCTAssertEqual(database.readData(), [fileInfo])
  }

  func testSaveAppendsRatherThanReplacing() {
    let first = makeFileInfo("first.txt")
    let second = makeFileInfo("second.txt")

    database.save(fileInfo: first)
    database.save(fileInfo: second)

    XCTAssertEqual(database.readData()?.count, 2)
  }

  func testReadDataIsSortedNewestFirst() {
    let older = makeFileInfo("older.txt", downloadedAt: Date(timeIntervalSince1970: 1_000))
    let newer = makeFileInfo("newer.txt", downloadedAt: Date(timeIntervalSince1970: 2_000))

    database.save(fileInfo: older)
    database.save(fileInfo: newer)

    XCTAssertEqual(database.readData()?.map(\.localFilename), ["newer.txt", "older.txt"])
  }

  func testReadDataReturnsNilOnDecodingError() {
    let dataFileURL = fileSaverMock.getDocumentsDirectoryURL(forFilename: "downloadedFiles.plist")
    try? "InvalidData".data(using: .utf8)?.write(to: dataFileURL)

    XCTAssertNil(database.readData())
  }

  func testRemoveDropsTheRecordAndDeletesTheFile() {
    let kept = makeFileInfo("kept.txt")
    let removed = makeFileInfo("removed.txt")
    database.save(fileInfo: kept)
    database.save(fileInfo: removed)

    database.remove(fileInfo: removed)

    XCTAssertEqual(database.readData()?.map(\.localFilename), ["kept.txt"])
    XCTAssertTrue(fileSaverMock.didRemoveFileCalled)
    XCTAssertEqual(fileSaverMock.removedFileURL, removed.localFileURL)
  }
}
