//
//  Download.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation

public class Download {
  public typealias ProgressHandler = (Float) -> ()
  public var progressHandler: ProgressHandler?
  
  internal var task: URLSessionDownloadTask?
  private var resumeData: Data?
  private let url: URL
  private let manager: DownloadManaging
  
  init(url: URL, manager: DownloadManaging) {
    self.url = url
    self.manager = manager
    self.task = manager.session.downloadTask(with: URLRequest(url: url))
  }
  
  func pause() {
    task?.cancel(byProducingResumeData: { data in
      self.resumeData = data
    })
    task = nil
  }
  
  func resume() {
    if let resumeData = self.resumeData {
      task = manager.session.downloadTask(withResumeData: resumeData)
    } else {
      task = manager.session.downloadTask(with: URLRequest(url: url))
    }
    task?.resume()
  }
}

