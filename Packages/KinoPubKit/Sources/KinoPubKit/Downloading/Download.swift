//
//  Download.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import KinoPubLogging
import OSLog

/// `Download` represents a downloadable resource. It provides methods for controlling the download,
/// such as pausing and resuming, and notifies about the progress through a progress handler.
public class Download<Meta: Codable & Equatable>: ObservableObject {
  /// The state of the download, such as not started, queued, in progress, or paused.
  public enum State: String {
    case notStarted
    case queued
    case inProgress
    case paused
  }
  
  /// URL for the download
  public let url: URL

  /// The current state of the download.
  public internal(set) var state: State = .notStarted

  /// Progress value
  @Published public private(set) var progress: Float = 0.0

  /// Bytes received so far and the expected total (for size / ETA display).
  @Published public private(set) var bytesWritten: Int64 = 0
  public private(set) var totalBytes: Int64 = 0

  /// Current transfer rate in bytes/sec (smoothed over ~0.5s samples).
  @Published public private(set) var speed: Double = 0

  private var lastSampleTime: Date?
  private var lastSampleBytes: Int64 = 0

  /// Estimated time remaining, or nil when it can't be computed yet.
  public var remainingTime: TimeInterval? {
    guard speed > 0, totalBytes > bytesWritten else { return nil }
    return Double(totalBytes - bytesWritten) / speed
  }

  /// Public metadata
  public let metadata: Meta

  // - Internal
  internal var task: URLSessionDownloadTask?

  /// Resume data produced when the download is paused. Exposed so the manager can persist it
  /// and restore paused downloads across app launches.
  internal var resumeData: Data?

  private let manager: any DownloadManaging

  /// Notifies the manager that this download's persistable state changed (paused / progress checkpoint).
  internal var onStateChange: ((Download<Meta>) -> Void)?

  /// Initializes a `Download` object.
  /// - Parameters:
  ///   - url: The URL of the resource to be downloaded.
  ///   - metadata: Metadata associated with the download.
  ///   - manager: An object that conforms to `DownloadManaging` to manage the download session.
  ///   - resumeData: Optional resume data used to restore a previously paused download.
  ///   - progress: Optional initial progress value used when restoring a download.
  public init(url: URL,
              metadata: Meta,
              manager: any DownloadManaging,
              resumeData: Data? = nil,
              progress: Float = 0.0) {
    self.url = url
    self.metadata = metadata
    self.manager = manager
    self.resumeData = resumeData
    self.progress = progress
    self.state = resumeData != nil ? .paused : .queued
    Logger.kit.debug("[DOWNLOAD] Download for url: \(url) is \(self.state.rawValue)")
  }

  /// Pauses the download. If the download is already paused or not in progress, this method has no effect.
  public func pause() {
    task?.cancel(byProducingResumeData: { [weak self] data in
      guard let self else { return }
      self.resumeData = data
      self.state = .paused
      Logger.kit.debug("[DOWNLOAD] Download for url: \(self.url.absoluteString) is paused")
      self.onStateChange?(self)
    })
    task = nil
  }

  /// Resumes the download. If the download is already in progress, this method has no effect.
  public func resume() {
    if let resumeData = self.resumeData {
      task = manager.session.downloadTask(withResumeData: resumeData)
    } else {
      task = manager.session.downloadTask(with: URLRequest(url: url))
    }
    state = .inProgress
    Logger.kit.debug("[DOWNLOAD] Download for url: \(self.url) is in progress")
    task?.resume()
    onStateChange?(self)
  }

  internal func updateProgress(_ progress: Float) {
    self.progress = progress
  }

  /// Updates byte counters and recomputes the transfer rate from ~0.5s samples.
  internal func updateTransfer(bytesWritten: Int64, totalBytes: Int64) {
    let now = Date()
    if let last = lastSampleTime {
      let dt = now.timeIntervalSince(last)
      if dt >= 0.5 {
        speed = max(0, Double(bytesWritten - lastSampleBytes) / dt)
        lastSampleTime = now
        lastSampleBytes = bytesWritten
      }
    } else {
      lastSampleTime = now
      lastSampleBytes = bytesWritten
    }
    self.bytesWritten = bytesWritten
    self.totalBytes = totalBytes
  }

}

extension Download: Identifiable {}
