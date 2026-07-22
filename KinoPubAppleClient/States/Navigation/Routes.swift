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
  /// The watching endpoints return only an id and artwork, so rows built from them
  /// route by id — `MediaItemView` fetches the full item anyway.
  case detailsById(Int)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(item)
    case .detailsById(let id):
      hasher.combine("detailsById")
      hasher.combine(id)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }
  
  static func == (lhs: MainRoutes, rhs: MainRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum CatalogRoutes: Hashable {
  case details(MediaItem)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(item)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }

  static func == (lhs: CatalogRoutes, rhs: CatalogRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum SearchRoutes: Hashable {
  case details(MediaItem)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(item)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }

  static func == (lhs: SearchRoutes, rhs: SearchRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum BookmarksRoutes: Hashable {
  case bookmark(Bookmark)
  case details(MediaItem)
  /// The folder rows are built from cards, which carry an id and artwork only, so they
  /// route by id — `MediaItemView` fetches the full item anyway.
  case detailsById(Int)
  case seasons([Season])
  case season(Season)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .bookmark(let bookmark):
      hasher.combine(bookmark)
    case .details(let item):
      hasher.combine(item)
    case .detailsById(let id):
      hasher.combine("detailsById")
      hasher.combine(id)
    case .season(let season):
      hasher.combine(season)
    case .seasons(let seasons):
      hasher.combine(seasons)
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }
  
  static func == (lhs: BookmarksRoutes, rhs: BookmarksRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}

enum DownloadsRoutes: Hashable {
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  
  func hash(into hasher: inout Hasher) {
    switch self {
    case .player(let item):
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(item.id)
    }
  }
  
  static func == (lhs: DownloadsRoutes, rhs: DownloadsRoutes) -> Bool {
    rhs.hashValue == lhs.hashValue
  }
}
