//
//  DownloadFlowTests.swift
//
//
//  End-to-end download pipeline checks: that a started download reports progress, finishes by
//  saving the file and leaves the active list, and that the background session is configured so
//  the system actually runs transfers (not discretionary).
//

import Foundation
import Combine
import XCTest
@testable import KinoPubKit

final class DownloadFlowTests: XCTestCase {

  var manager: DownloadManager<TestMeta>!
  var fileSaver: FileSaverMock!
  let url = URL(string: "http://example.com/movie.mp4")!
  let metadata = TestMeta(id: 1, title: "movie")

  override func setUp() {
    super.setUp()
    fileSaver = FileSaverMock()
    manager = DownloadManager(fileSaver: fileSaver,
                              database: DownloadedFilesDatabase(fileSaver: fileSaver))
  }

  override func tearDown() {
    manager = nil
    fileSaver = nil
    super.tearDown()
  }

  /// Regression guard for the fix: background transfers must NOT be discretionary (otherwise the
  /// system can defer them indefinitely and downloads never appear to start).
  func testSession_IsNotDiscretionary() {
    XCTAssertFalse(manager.session.configuration.isDiscretionary)
    XCTAssertTrue(manager.session.configuration.sessionSendsLaunchEvents)
  }

  /// Full pipeline: start → byte progress → finish → file saved and removed from the active list.
  func testDownloadFlow_progressThenFinishSavesFile() {
    let task = URLSessionDownloadTaskMock(url: url)
    let download = manager.startDownload(url: url, withMetadata: metadata)
    download.task = task

    XCTAssertNotNil(manager.activeDownloads[url])
    XCTAssertEqual(download.state, .inProgress)

    // Progress reaches 50%.
    let progressExpectation = expectation(description: "progress reaches 0.5")
    let cancellable = download.$progress
      .dropFirst()
      .sink { if $0 == 0.5 { progressExpectation.fulfill() } }
    manager.urlSession(manager.session,
                       downloadTask: task,
                       didWriteData: 512,
                       totalBytesWritten: 512,
                       totalBytesExpectedToWrite: 1024)
    wait(for: [progressExpectation], timeout: 1.0)
    cancellable.cancel()

    // Finishing saves the file to the documents directory and clears the active entry.
    let location = URL(fileURLWithPath: "/tmp/movie.mp4")
    manager.urlSession(manager.session, downloadTask: task, didFinishDownloadingTo: location)

    XCTAssertTrue(fileSaver.didSaveFileCalled)
    XCTAssertEqual(fileSaver.savedFileSourceURL, location)
    XCTAssertEqual(fileSaver.savedFileDestinationURL,
                   fileSaver.getDocumentsDirectoryURL(forFilename: "movie.mp4"))
    XCTAssertNil(manager.activeDownloads[url], "A finished download is removed from the active list")
  }
}
