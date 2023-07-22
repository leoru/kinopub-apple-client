//
//  DownloadManager.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import OSLog
import KinoPubLogging

public protocol DownloadManaging {
  var session: URLSession { get }
  func startDownload(url: URL) -> Download
  func completeDownload(_ url: URL)
}

public class DownloadManager: NSObject, URLSessionDownloadDelegate, DownloadManaging {
  public var activeDownloads: [URL: Download] = [:]
  private var fileSaver: FileSaving
  private var downloadedFilesDatabase: DownloadedFilesDataWriting
  
  init(fileSaver: FileSaving, downloadedFilesDatabase: DownloadedFilesDataWriting) {
    self.fileSaver = fileSaver
    self.downloadedFilesDatabase = downloadedFilesDatabase
  }
  
  lazy public var session: URLSession = {
    let identifier = "com.kinopub.backgroundDownloadSession"
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()
  
  public func startDownload(url: URL) -> Download {
    let download = Download(url: url, manager: self)
    download.task?.resume()
    activeDownloads[url] = download
    return download
  }
  
  public func completeDownload(_ url: URL) {
    activeDownloads[url] = nil
  }
  
  // MARK: URLSessionDownloadDelegate methods
  
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let sourceURL = downloadTask.originalRequest?.url else { return }
    Logger.kit.debug("Download finished: \(location)")
    
    let destinationURL = fileSaver.getDocumentsDirectoryURL(forFilename: sourceURL.lastPathComponent)
    
    do {
      try fileSaver.saveFile(from: location, to: destinationURL)
      Logger.kit.info("File: \(location) moved to documents folder")
      
      let fileInfo = DownloadedFileInfo(originalURL: sourceURL, localFilename: sourceURL.lastPathComponent, downloadDate: Date())
      downloadedFilesDatabase.save(fileInfo: fileInfo)
    } catch {
      Logger.kit.error("Error during moving file: \(error)")
    }
    
    completeDownload(sourceURL)
  }
  
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    if totalBytesExpectedToWrite > 0, let download = activeDownloads[downloadTask.originalRequest?.url ?? URL(fileURLWithPath: "")] {
      let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
      DispatchQueue.main.async {
        download.progressHandler?(progress)
      }
    }
  }
  
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error, let url = task.originalRequest?.url {
      Logger.kit.debug("Download error for \(url): \(error)")
      completeDownload(url)
    }
  }
}
