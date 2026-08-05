//
//  Routes.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import KinoPubBackend

/// Single destination vocabulary for every tab stack. Stacks stay per-tab; the
/// cases and `Equatable`/`Hashable` rules are shared so deep links and Back titles
/// do not need five parallel mappings.
enum Route: Hashable {
  case details(MediaItem)
  /// Watching endpoints / cards often carry only an id and artwork.
  case detailsById(Int)
  case history
  case bookmark(Bookmark)
  case seasons([Season])
  case season(Season)
  case person(MediaPerson)
  case player(any PlayableItem)
  case trailerPlayer(any PlayableItem)
  /// The curated-collections browser (`GET /v1/collections`).
  case collections
  /// One collection's full item grid (`GET /v1/collections/view`).
  case collection(Collection)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let item):
      hasher.combine(0)
      hasher.combine(item)
    case .detailsById(let id):
      hasher.combine(1)
      hasher.combine(id)
    case .history:
      hasher.combine(2)
    case .bookmark(let bookmark):
      hasher.combine(3)
      hasher.combine(bookmark)
    case .seasons(let seasons):
      hasher.combine(4)
      hasher.combine(seasons)
    case .season(let season):
      hasher.combine(5)
      hasher.combine(season)
    case .person(let person):
      hasher.combine(6)
      hasher.combine(person)
    case .player(let item):
      hasher.combine(7)
      hasher.combine(item.id)
    case .trailerPlayer(let item):
      hasher.combine(8)
      hasher.combine(item.id)
    case .collections:
      hasher.combine(9)
    case .collection(let collection):
      hasher.combine(10)
      hasher.combine(collection)
    }
  }

  static func == (lhs: Route, rhs: Route) -> Bool {
    switch (lhs, rhs) {
    case (.details(let a), .details(let b)):
      return a == b
    case (.detailsById(let a), .detailsById(let b)):
      return a == b
    case (.history, .history):
      return true
    case (.bookmark(let a), .bookmark(let b)):
      return a == b
    case (.seasons(let a), .seasons(let b)):
      return a == b
    case (.season(let a), .season(let b)):
      return a == b
    case (.person(let a), .person(let b)):
      return a == b
    case (.player(let a), .player(let b)):
      return a.id == b.id
    case (.trailerPlayer(let a), .trailerPlayer(let b)):
      return a.id == b.id
    case (.collections, .collections):
      return true
    case (.collection(let a), .collection(let b)):
      return a == b
    default:
      return false
    }
  }
}

/// Legacy names kept as aliases so call sites migrate without five duplicate enums.
typealias MainRoutes = Route
typealias CatalogRoutes = Route
typealias SearchRoutes = Route
typealias BookmarksRoutes = Route
typealias DownloadsRoutes = Route
