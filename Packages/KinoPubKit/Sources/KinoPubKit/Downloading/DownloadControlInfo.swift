//
//  DownloadControlInfo.swift
//
//
//  Created by Claude on 24.06.2026.
//

import Foundation

/// `DownloadControlInfo` describes an in-progress or paused download so it can be persisted
/// and restored across app launches.
///
/// It has the following properties:
///
/// - originalURL: The original URL of the resource being downloaded.
///
/// - resumeData: Optional resume data produced when the download was paused. May be `nil`
///   if the download was in progress and no resume data was captured.
///
/// - progress: The last known progress value (0.0...1.0).
///
/// - metadata: Generic metadata associated with the download. Metadata must conform to Codable and Equatable.
///
/// `DownloadControlInfo` conforms to Codable so it can be encoded/decoded with the same
/// `FileSaver`/plist approach used by `DownloadedFilesDatabase`.
public struct DownloadControlInfo<Meta: Codable & Equatable>: Codable {
  public let originalURL: URL
  public let resumeData: Data?
  public let progress: Float
  public let metadata: Meta

  public init(originalURL: URL, resumeData: Data?, progress: Float, metadata: Meta) {
    self.originalURL = originalURL
    self.resumeData = resumeData
    self.progress = progress
    self.metadata = metadata
  }
}

extension DownloadControlInfo: Equatable {}
