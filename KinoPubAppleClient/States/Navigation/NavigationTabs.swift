//
//  NavigationTabs.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation

enum NavigationTabs: Hashable {
  case search
  case home
  case movies
  case series
  case watchlist
  case recentlyWatched
  case downloads
  case bookmarks
  /// A bookmark folder pinned as its own sidebar tab.
  case bookmark(Int)
  case settings
}
