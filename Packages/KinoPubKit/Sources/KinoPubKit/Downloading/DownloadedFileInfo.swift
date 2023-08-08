//
//  DownloadedFileInfo.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation

/// DownloadedFileInfo is a struct that contains information about a downloaded file.
///
/// It has the following properties:
///
/// - originalURL: The original URL of the file that was downloaded.
///
/// - localFilename: The filename of the downloaded file saved locally.
/// 
/// - downloadDate: The date when the file was downloaded.
///
/// - metadata: Generic metadata associated with the file. Metadata must conform to Codable and Equatable.
///
/// DownloadedFileInfo conforms to Codable so it can be encoded/decoded.
/// The Meta generic type allows custom metadata types to be stored for each downloaded file.
public struct DownloadedFileInfo<Meta: Codable & Equatable>: Codable {
  public let originalURL: URL
  public let localFilename: String
  public let downloadDate: Date
  public let metadata: Meta
}

extension DownloadedFileInfo: Equatable {}
