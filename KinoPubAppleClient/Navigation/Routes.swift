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
}

enum BookmarksRoutes: Hashable {
  case details(MediaItem)
}
