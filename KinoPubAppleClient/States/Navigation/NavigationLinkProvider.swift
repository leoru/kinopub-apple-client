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
  /// A collection shelf's header — the collection's own page.
  func collection(_ collection: Collection) -> any Hashable
}

/// One provider for every tab stack — destinations are always `Route`.
struct AppRoutesLinkProvider: NavigationLinkProvider {
  func link(for item: MediaItem) -> any Hashable { Route.details(item) }
  func player(for item: any PlayableItem) -> any Hashable { Route.player(item) }
  func trailerPlayer(for item: any PlayableItem) -> any Hashable { Route.trailerPlayer(item) }
  func seasons(for seasons: [Season]) -> any Hashable { Route.seasons(seasons) }
  func season(for season: Season) -> any Hashable { Route.season(season) }
  func person(for person: MediaPerson) -> any Hashable { Route.person(person) }
  func collection(_ collection: Collection) -> any Hashable { Route.collection(collection) }
}

typealias MainRoutesLinkProvider = AppRoutesLinkProvider
typealias CatalogRoutesLinkProvider = AppRoutesLinkProvider
typealias SearchRoutesLinkProvider = AppRoutesLinkProvider
typealias BookmarksRoutesLinkProvider = AppRoutesLinkProvider
typealias DownloadsRoutesLinkProvider = AppRoutesLinkProvider
