//
//  NavigationLinkProvider.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

protocol NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable
  func player(for item: MediaItem) -> any Hashable
}

struct MainRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    return MainRoutes.details(item)
  }
  
  func player(for item: MediaItem) -> any Hashable {
    return MainRoutes.player(item)
  }
}

struct BookmarksRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    return BookmarksRoutes.details(item)
  }
  
  func player(for item: MediaItem) -> any Hashable {
    return BookmarksRoutes.player(item)
  }
}

struct DownloadsRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    return BookmarksRoutes.details(item)
  }
  
  func player(for item: MediaItem) -> any Hashable {
    return DownloadsRoutes.player(item)
  }
}
