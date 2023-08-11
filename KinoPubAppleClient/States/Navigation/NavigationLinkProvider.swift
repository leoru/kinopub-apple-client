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
  func trailerPlayer(for item: MediaItem) -> any Hashable
}

struct MainRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    MainRoutes.details(item)
  }
  
  func player(for item: MediaItem) -> any Hashable {
    MainRoutes.player(item)
  }
  
  func trailerPlayer(for item: MediaItem) -> any Hashable {
    MainRoutes.trailerPlayer(item)
  }
}

struct BookmarksRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.details(item)
  }
  
  func player(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.player(item)
  }
  
  func trailerPlayer(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.trailerPlayer(item)
  }
}

struct DownloadsRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.details(item)
  }
  
  func player(for item: MediaItem) -> any Hashable {
    DownloadsRoutes.player(item)
  }
  
  func trailerPlayer(for item: MediaItem) -> any Hashable {
    DownloadsRoutes.trailerPlayer(item)
  }
}
