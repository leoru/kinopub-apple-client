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
  var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta> { get set }
}

protocol DownloadManagerProvider {
  var downloadManager: DownloadManager<DownloadMeta> { get set }
}

protocol FileSaverProvider {
  var fileSaver: FileSaving { get set }
}
