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
  associatedtype Meta: Codable & Equatable
  
  var session: URLSession { get }
  func startDownload(url: URL, withMetadata metadata: Meta) -> Download<Meta>
  func completeDownload(_ url: URL)
}

public class DownloadManager<Meta: Codable & Equatable>: NSObject, URLSessionDownloadDelegate, DownloadManaging {
  @Published public var activeDownloads: [URL: Download<Meta>] = [:]
  private var fileSaver: FileSaving
  private var database: DownloadedFilesDatabase<Meta>

  public init(fileSaver: FileSaving, database: DownloadedFilesDatabase<Meta>) {
    self.fileSaver = fileSaver
    self.database = database
  }

  lazy public var session: URLSession = {
    let identifier = "com.kinopub.backgroundDownloadSession"
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  public func startDownload(url: URL, withMetadata metadata: Meta) -> Download<Meta> {
    let download = Download(url: url, metadata: metadata, manager: self)
    download.task?.resume()
    activeDownloads[url] = download
    return download
  }

  public func completeDownload(_ url: URL) {
    activeDownloads[url] = nil
  }

  // MARK: URLSessionDownloadDelegate methods

  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let sourceURL = downloadTask.originalRequest?.url, let download = activeDownloads[sourceURL] else { return }
    Logger.kit.debug("[DOWNLOAD] Download finished: \(location)")

    let destinationURL = fileSaver.getDocumentsDirectoryURL(forFilename: sourceURL.lastPathComponent)

    do {
      try fileSaver.saveFile(from: location, to: destinationURL)
      Logger.kit.info("[DOWNLOAD] File: \(location) moved to documents folder")

      let fileInfo = DownloadedFileInfo(originalURL: sourceURL, localFilename: sourceURL.lastPathComponent, downloadDate: Date(), metadata: download.metadata)
      database.save(fileInfo: fileInfo)
    } catch {
      Logger.kit.error("[DOWNLOAD] Error during moving file: \(error)")
    }

    completeDownload(sourceURL)
  }

  public func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
    if totalBytesExpectedToWrite > 0, let download = activeDownloads[downloadTask.originalRequest?.url ?? URL(fileURLWithPath: "")] {
      let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
      Logger.kit.error("[DOWNLOAD] progress for download: \(download.url), value: \(progress)")
      DispatchQueue.main.async {
        download.updateProgress(progress)
      }
    }
  }

  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error, let url = task.originalRequest?.url {
      Logger.kit.debug("[DOWNLOAD] Download error for \(url): \(error)")
      completeDownload(url)
    }
  }
}
