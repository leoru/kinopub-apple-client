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
  /// Where a name in the credits leads: the catalog narrowed to that person.
  func person(for person: MediaPerson) -> any Hashable
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

  func person(for person: MediaPerson) -> any Hashable {
    MainRoutes.person(person)
  }
}

struct CatalogRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable { CatalogRoutes.details(item) }
  func player(for item: any PlayableItem) -> any Hashable { CatalogRoutes.player(item) }
  func trailerPlayer(for item: any PlayableItem) -> any Hashable { CatalogRoutes.trailerPlayer(item) }
  func seasons(for seasons: [Season]) -> any Hashable { CatalogRoutes.seasons(seasons) }
  func season(for season: Season) -> any Hashable { CatalogRoutes.season(season) }
  func person(for person: MediaPerson) -> any Hashable { CatalogRoutes.person(person) }
}

struct SearchRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable {
    SearchRoutes.details(item)
  }

  func player(for item: any PlayableItem) -> any Hashable {
    SearchRoutes.player(item)
  }

  func trailerPlayer(for item: any PlayableItem) -> any Hashable {
    SearchRoutes.trailerPlayer(item)
  }

  func seasons(for seasons: [Season]) -> any Hashable {
    SearchRoutes.seasons(seasons)
  }

  func season(for season: Season) -> any Hashable {
    SearchRoutes.season(season)
  }

  func person(for person: MediaPerson) -> any Hashable {
    SearchRoutes.person(person)
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

  func person(for person: MediaPerson) -> any Hashable {
    BookmarksRoutes.person(person)
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

  func person(for person: MediaPerson) -> any Hashable {
    ""
  }
}
