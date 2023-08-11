//
//  Routes.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

enum MainRoutes: Hashable {
  case details(MediaItem)
  case player(MediaItem)
  case trailerPlayer(MediaItem)
}

enum BookmarksRoutes: Hashable {
  case bookmark(Bookmark)
  case details(MediaItem)
  case player(MediaItem)
  case trailerPlayer(MediaItem)
}

enum DownloadsRoutes: Hashable {
  case player(MediaItem)
  case trailerPlayer(MediaItem)
}
