//
//  DownloadManagerTests.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import XCTest
@testable import KinoPubKit

class DownloadManagerTests: XCTestCase {

  // MARK: - Test Variables

  var downloadManager: DownloadManager<TestMeta>!
  var database: DownloadedFilesDatabase<TestMeta>!
  var fileSaverMock: FileSaverMock!

  private let url = URL(string: "http://example.com/testfile.txt")!
  private let metadata = TestMeta(id: 1, title: "Test")

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()

    fileSaverMock = FileSaverMock()
    database = DownloadedFilesDatabase<TestMeta>(fileSaver: fileSaverMock)
    downloadManager = DownloadManager<TestMeta>(fileSaver: fileSaverMock, database: database)
  }

  override func tearDown() {
    downloadManager = nil
    database = nil
    fileSaverMock = nil
    super.tearDown()
  }

  // MARK: - Helpers

  /// Registers a download without going through `startDownload`, which would spin up
  /// the shared background `URLSession`. Only one test does that on purpose.
  @discardableResult
  private func registerDownload() -> Download<TestMeta> {
    let download = Download(url: url, metadata: metadata, manager: downloadManager)
    downloadManager.activeDownloads[url] = download
    return download
  }

  // MARK: - Test Methods

  func testStartDownloadRegistersAnActiveDownload() {
    let download = downloadManager.startDownload(url: url, withMetadata: metadata)

    XCTAssertEqual(download.url, url)
    XCTAssertEqual(download.metadata, metadata)
    XCTAssertEqual(download.state, .inProgress)
    XCTAssertNotNil(downloadManager.activeDownloads[url])

    download.pause()
    downloadManager.completeDownload(url)
  }

  func testCompleteDownloadRemovesTheActiveDownload() {
    registerDownload()

    downloadManager.completeDownload(url)

    XCTAssertNil(downloadManager.activeDownloads[url])
  }

  func testRemoveDownloadRemovesTheActiveDownload() {
    registerDownload()

    downloadManager.removeDownload(for: url)

    XCTAssertNil(downloadManager.activeDownloads[url])
  }

  func testRemoveDownloadIsANoOpForAnUnknownURL() {
    registerDownload()

    downloadManager.removeDownload(for: URL(string: "http://example.com/other.txt")!)

    XCTAssertNotNil(downloadManager.activeDownloads[url])
  }

  func testFinishingADownloadSavesTheFileAndRecordsIt() {
    registerDownload()
    let location = URL(fileURLWithPath: "/path/to/temporary/location.txt")
    let task = URLSessionDownloadTaskMock(url: url)

    downloadManager.urlSession(.shared, downloadTask: task, didFinishDownloadingTo: location)

    XCTAssertTrue(fileSaverMock.didSaveFileCalled)
    XCTAssertEqual(fileSaverMock.savedFileSourceURL, location)
    XCTAssertEqual(fileSaverMock.savedFileDestinationURL,
                   fileSaverMock.getDocumentsDirectoryURL(forFilename: "testfile.txt"))
    XCTAssertEqual(database.readData()?.map(\.localFilename), ["testfile.txt"])
    XCTAssertNil(downloadManager.activeDownloads[url], "the download should no longer be active")
  }

  func testFinishingADownloadRecordsNothingWhenSavingFails() {
    registerDownload()
    fileSaverMock.shouldThrowError = true
    let task = URLSessionDownloadTaskMock(url: url)

    downloadManager.urlSession(.shared,
                               downloadTask: task,
                               didFinishDownloadingTo: URL(fileURLWithPath: "/tmp/location.txt"))

    XCTAssertNil(database.readData())
    XCTAssertNil(downloadManager.activeDownloads[url])
  }

  func testProgressIsPublishedWhileDownloading() {
    let download = registerDownload()
    let task = URLSessionDownloadTaskMock(url: url)
    let progressUpdated = expectation(description: "progress updated")

    let observation = download.$progress
      .dropFirst()
      .sink { progress in
        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
        progressUpdated.fulfill()
      }

    downloadManager.urlSession(.shared,
                               downloadTask: task,
                               didWriteData: 1024,
                               totalBytesWritten: 1024,
                               totalBytesExpectedToWrite: 2048)

    wait(for: [progressUpdated], timeout: 1.0)
    observation.cancel()
  }
}

// MARK: - Mock Classes

class URLSessionDownloadTaskMock: URLSessionDownloadTask {
  private let url: URL?

  init(url: URL? = nil) {
    self.url = url
  }

  override var originalRequest: URLRequest? {
    guard let url else { return nil }
    return URLRequest(url: url)
  }

  override func resume() {}

  override func cancel() {}

  override func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
    completionHandler(nil)
  }
}
