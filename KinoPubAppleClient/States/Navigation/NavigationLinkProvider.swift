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
  func player(for item: any PlayableItem) -> any Hashable
  func trailerPlayer(for item: any PlayableItem) -> any Hashable
  func seasons(for seasons: [Season]) -> any Hashable
  func season(for season: Season) -> any Hashable
}

struct MainRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    MainRoutes.details(item)
  }
  
  func player(for item: any PlayableItem) -> any Hashable {
    MainRoutes.player(item)
  }
  
  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    MainRoutes.trailerPlayer(item)
  }
  
  func seasons(for seasons: [Season]) -> any Hashable {
    MainRoutes.seasons(seasons)
  }
  
  func season(for season: Season) -> any Hashable {
    MainRoutes.season(season)
  }
}

struct BookmarksRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.details(item)
  }
  
  func player(for item: any PlayableItem) -> any Hashable {
    BookmarksRoutes.player(item)
  }
  
  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    BookmarksRoutes.trailerPlayer(item)
  }
  
  func seasons(for seasons: [Season]) -> any Hashable {
    BookmarksRoutes.seasons(seasons)
  }
  
  func season(for season: Season) -> any Hashable {
    BookmarksRoutes.season(season)
  }
}

struct DownloadsRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    BookmarksRoutes.details(item)
  }
  
  func player(for item: any PlayableItem) -> any Hashable {
    DownloadsRoutes.player(item)
  }
  
  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    DownloadsRoutes.trailerPlayer(item)
  }
  
  func seasons(for seasons: [Season]) -> any Hashable {
    ""
  }
  
  func season(for season: Season) -> any Hashable {
    ""
  }
}
