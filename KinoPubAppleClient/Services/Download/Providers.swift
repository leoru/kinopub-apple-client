//
//  Providers.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import KinoPubKit
import KinoPubBackend

protocol DownloadedFilesDatabaseProvider {
  var downloadedFilesDatabase: DownloadedFilesDatabase<MediaItem> { get set }
}

protocol DownloadManagerProvider {
  var downloadManager: DownloadManager<MediaItem> { get set }
}

protocol FileSaverProvider {
  var fileSaver: FileSaving { get set }
}
