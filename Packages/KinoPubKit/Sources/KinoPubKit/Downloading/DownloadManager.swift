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
  func removeDownload(for url: URL)
  func completeDownload(_ url: URL)
}

/// Lets a download's metadata supply a human-readable base filename (no extension), so saved files
/// read like "Бесстыжие S10E1 (480p).mp4" in the Files app instead of an opaque CDN hash.
public protocol DownloadFileNaming {
  var downloadFileBaseName: String? { get }
}

public class DownloadManager<Meta: Codable & Equatable>: NSObject, URLSessionDownloadDelegate, DownloadManaging {
  @Published public var activeDownloads: [URL: Download<Meta>] = [:]
  private var fileSaver: FileSaving
  private var database: DownloadedFilesDatabase<Meta>
  private var controlDatabase: DownloadsControlDatabase<Meta>?

  /// Completion handler stored by the app delegate when the system relaunches the app to finish
  /// background URLSession events. Invoked once the session reports it finished delivering events.
  public var backgroundCompletionHandler: (() -> Void)?

  /// Invoked on the main thread when a download finishes successfully. The app uses this to post a
  /// local notification and to advance season-download groups. Kept generic so KinoPubKit stays
  /// UI- and platform-agnostic.
  public var onDownloadFinished: ((_ url: URL, _ metadata: Meta) -> Void)?

  /// Invoked on the main thread when a download fails with an error.
  public var onDownloadFailed: ((_ url: URL, _ metadata: Meta, _ error: Error) -> Void)?

  public init(fileSaver: FileSaving,
              database: DownloadedFilesDatabase<Meta>,
              controlDatabase: DownloadsControlDatabase<Meta>? = nil) {
    self.fileSaver = fileSaver
    self.database = database
    self.controlDatabase = controlDatabase
    super.init()
    restoreDownloads()
  }

  lazy public var session: URLSession = {
    let identifier = "com.kinopub.backgroundDownloadSession"
    let config = URLSessionConfiguration.background(withIdentifier: identifier)
    // Without this the system treats background transfers as discretionary and may defer them
    // indefinitely (downloads appear stuck / never start, especially in the simulator).
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.allowsCellularAccess = true
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  public func startDownload(url: URL, withMetadata metadata: Meta) -> Download<Meta> {
    let download = Download(url: url, metadata: metadata, manager: self)
    observeStateChanges(of: download)
    download.resume()
    activeDownloads[url] = download
    persist(download)
    return download
  }

  public func removeDownload(for url: URL) {
    guard let download = activeDownloads[url] else {
      return
    }

    download.pause()
    activeDownloads[url] = nil
    controlDatabase?.remove(url: url)
  }

  public func completeDownload(_ url: URL) {
    // Delegate callbacks arrive on a background queue; `activeDownloads` is @Published and drives
    // the UI, so its mutations must land on the main thread.
    onMain { self.activeDownloads[url] = nil }
    controlDatabase?.remove(url: url)
  }

  /// Runs `work` synchronously if already on the main thread (keeps unit-test assertions simple),
  /// otherwise hops to the main queue.
  private func onMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }

  /// Rebuilds `activeDownloads` from persisted control info as paused `Download` objects so the user
  /// can resume them after relaunching the app. Resume data may be `nil`, which is handled gracefully.
  public func restoreDownloads() {
    guard let stored = controlDatabase?.readData(), !stored.isEmpty else { return }
    for info in stored {
      let download = Download(url: info.originalURL,
                              metadata: info.metadata,
                              manager: self,
                              resumeData: info.resumeData,
                              progress: info.progress)
      observeStateChanges(of: download)
      activeDownloads[info.originalURL] = download
      Logger.kit.debug("[DOWNLOAD] restored paused download for: \(info.originalURL)")
    }
  }

  // MARK: - Persistence helpers

  private func observeStateChanges(of download: Download<Meta>) {
    download.onStateChange = { [weak self] download in
      self?.persist(download)
    }
  }

  private func persist(_ download: Download<Meta>) {
    let info = DownloadControlInfo(originalURL: download.url,
                                   resumeData: download.resumeData,
                                   progress: download.progress,
                                   metadata: download.metadata)
    controlDatabase?.save(controlInfo: info)
  }

  // MARK: URLSessionDownloadDelegate methods

  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let sourceURL = downloadTask.originalRequest?.url, let download = activeDownloads[sourceURL] else { return }
    Logger.kit.debug("[DOWNLOAD] Download finished: \(location)")

    // URLSession reports an HTTP error (403 / expired signature / etc.) as a successful "finish" and
    // hands us the tiny error body. Saving it produced broken ~160-byte "videos", so reject anything
    // that isn't a 2xx response or is implausibly small for media.
    if let http = downloadTask.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      Logger.kit.error("[DOWNLOAD] HTTP \(http.statusCode) for \(sourceURL) — discarding error body")
      try? FileManager.default.removeItem(at: location)
      completeDownload(sourceURL)
      return
    }
    // Only reject when we can actually read a (small) size — a real video is many MB, so anything
    // under ~100 KB is an error page. If the file's attributes can't be read, fall through and let
    // the file saver handle it (keeps this mockable in tests).
    if let attrs = try? FileManager.default.attributesOfItem(atPath: location.path),
       let fileSize = attrs[.size] as? Int64, fileSize < 100_000 {
      Logger.kit.error("[DOWNLOAD] file too small (\(fileSize) bytes) for \(sourceURL) — likely an error page, discarding")
      try? FileManager.default.removeItem(at: location)
      completeDownload(sourceURL)
      return
    }

    // Prefer a human-readable filename (keeps the source extension); fall back to the URL's last path
    // component. This is what shows in the Files app.
    let filename: String = {
      let ext = sourceURL.pathExtension
      if let base = (download.metadata as? DownloadFileNaming)?.downloadFileBaseName, !base.isEmpty {
        return ext.isEmpty ? base : "\(base).\(ext)"
      }
      return sourceURL.lastPathComponent
    }()
    let destinationURL = fileSaver.getDocumentsDirectoryURL(forFilename: filename)

    do {
      try fileSaver.saveFile(from: location, to: destinationURL)
      Logger.kit.info("[DOWNLOAD] File: \(location) moved to documents folder as \(filename)")

      let fileInfo = DownloadedFileInfo(originalURL: sourceURL, localFilename: filename, downloadDate: Date(), metadata: download.metadata)
      database.save(fileInfo: fileInfo)
    } catch {
      Logger.kit.error("[DOWNLOAD] Error during moving file: \(error)")
    }

    let metadata = download.metadata
    onMain { self.onDownloadFinished?(sourceURL, metadata) }
    completeDownload(sourceURL)
  }

  public func urlSession(_ session: URLSession,
                         downloadTask: URLSessionDownloadTask,
                         didWriteData bytesWritten: Int64,
                         totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
    if totalBytesExpectedToWrite > 0, let download = activeDownloads[downloadTask.originalRequest?.url ?? URL(fileURLWithPath: "")] {
      let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
      Logger.kit.debug("[DOWNLOAD] progress for download: \(download.url), value: \(progress)")
      // Persist a progress checkpoint (throttled to whole-percent steps) so a partially
      // completed download survives a relaunch without writing the plist on every callback.
      let shouldCheckpoint = Int(progress * 100) != Int(download.progress * 100)
      DispatchQueue.main.async {
        download.updateProgress(progress)
        download.updateTransfer(bytesWritten: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
        if shouldCheckpoint {
          self.persist(download)
        }
      }
    }
  }

  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error = error, let url = task.originalRequest?.url {
      Logger.kit.debug("[DOWNLOAD] Download error for \(url): \(error)")
      // A cancellation that produced resume data is a pause, not a failure — don't notify the user.
      let isPause = (error as NSError).code == NSURLErrorCancelled
      if !isPause, let metadata = activeDownloads[url]?.metadata {
        onMain { self.onDownloadFailed?(url, metadata, error) }
      }
      completeDownload(url)
    }
  }

  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    Logger.kit.debug("[DOWNLOAD] background session finished events")
    DispatchQueue.main.async {
      let handler = self.backgroundCompletionHandler
      self.backgroundCompletionHandler = nil
      handler?()
    }
  }
}
