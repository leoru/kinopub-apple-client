//
//  File.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import XCTest
@testable import KinoPubKit

class DownloadManagerTests: XCTestCase {
  
  // MARK: - Test Variables
  
  var downloadManager: DownloadManager!
  var downloadedFilesDatabase: DownloadedFilesDatabase!
  var fileSaverMock: FileSaverMock!
  
  // MARK: - Test Setup
  
  override func setUp() {
    super.setUp()
    
    fileSaverMock = FileSaverMock()
    downloadManager = DownloadManager(fileSaver: fileSaverMock,
                                      downloadedFilesDatabase: DownloadedFilesDatabase(fileSaver: fileSaverMock))
  }
  
  override func tearDown() {
    downloadManager = nil
    fileSaverMock = nil
    super.tearDown()
  }
  
  // MARK: - Test Methods
  
  func testStartDownload() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    
    // Act
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url, resumeBlock: {})
    let download = downloadManager.startDownload(url: url)
    download.task = downloadTaskMock
    
    // Assert
    XCTAssertNotNil(download)
    XCTAssertTrue(download.task?.state == .running) // The task should be resumed.
    XCTAssertNotNil(downloadManager.activeDownloads[url])
  }
  
  func testCompleteDownload() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url, resumeBlock: {})
    let download = downloadManager.startDownload(url: url)
    download.task = downloadTaskMock
    
    // Act
    downloadManager.completeDownload(url)
    
    // Assert
    XCTAssertNil(downloadManager.activeDownloads[url])
  }
  
  func testDidFinishDownloadingTo_Success() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    let locationURL = URL(fileURLWithPath: "/path/to/temporary/location.txt")
    
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url) {
      // In this test, we do not trigger the completion handler. Instead, we will manually verify the actions taken by the DownloadManager.
    }
    
    downloadTaskMock.triggerCompletion(with: locationURL, response: nil, error: nil)
    
    // Set the download task on the Download instance.
    let download = downloadManager.startDownload(url: url)
    download.task = downloadTaskMock
    
    // Act
    downloadManager.urlSession(downloadManager.session,
                               downloadTask: downloadTaskMock,
                               didFinishDownloadingTo: locationURL)
    
    // Assert
    XCTAssertTrue(fileSaverMock.didSaveFileCalled)
    XCTAssertEqual(fileSaverMock.savedFileSourceURL, locationURL)
    XCTAssertEqual(fileSaverMock.savedFileDestinationURL, fileSaverMock.getDocumentsDirectoryURL(forFilename: "testfile.txt"))
  }
  
  func testDidWriteData_ProgressHandlerCalled() {
    // Arrange
    let url = URL(string: "http://example.com/testfile.txt")!
    let downloadTaskMock = URLSessionDownloadTaskMock(url: url, resumeBlock: {})
    let download = downloadManager.startDownload(url: url)
    download.task = downloadTaskMock
    
    var progressHandlerCalled = false
    download.progressHandler = { progress in
      progressHandlerCalled = true
    }
    
    // Act
    downloadManager.urlSession(downloadManager.session,
                               downloadTask: downloadTaskMock,
                               didWriteData: 1024,
                               totalBytesWritten: 1024,
                               totalBytesExpectedToWrite: 2048)
    
    // Assert
    XCTAssertTrue(progressHandlerCalled)
  }
  
}

// MARK: - Mock Classes

class URLSessionDownloadTaskMock: URLSessionDownloadTask {
  typealias CompletionHandler = (URL?, URLResponse?, Error?) -> Void
  
  private let completionHandler: CompletionHandler?
  private let url: URL?
  private let resumeBlock: () -> Void
  
  init(url: URL? = nil, completionHandler: CompletionHandler? = nil, resumeBlock: @escaping () -> Void) {
    self.url = url
    self.completionHandler = completionHandler
    self.resumeBlock = resumeBlock
  }
  
  override var originalRequest: URLRequest? {
    if let url = url {
      return URLRequest(url: url)
    }
    return nil
  }
  
  override func resume() {
    resumeBlock()
  }
  
  override func cancel() {}
  
  override func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
    completionHandler(nil)
  }
  
  func triggerCompletion(with location: URL?, response: URLResponse?, error: Error?) {
    completionHandler?(location, response, error)
  }
}
