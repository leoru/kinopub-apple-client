//
//  CollectionsService.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

protocol CollectionsService {
  func fetchCollections(page: Int?, sort: String?) async throws -> CollectionsData
  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem])
  /// Which collections a title sits in. Best-effort by contract: the endpoint was
  /// captured from the PWA on its own host branch, so callers treat a throw as "none".
  func fetchCollections(forItem id: Int) async throws -> [Collection]
}

protocol CollectionsServiceProvider {
  var collectionsService: CollectionsService { get set }
}

struct CollectionsServiceMock: CollectionsService {

  func fetchCollections(page: Int?, sort: String?) async throws -> CollectionsData {
    .mock(data: [
      Collection.mock(id: 1, title: "Mock Collection"),
      Collection.mock(id: 2, title: "Another Collection", watchers: 42, views: 900)
    ])
  }

  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem]) {
    (Collection.mock(id: id), [MediaItem.mock(id: 101), MediaItem.mock(id: 102)])
  }

  func fetchCollections(forItem id: Int) async throws -> [Collection] {
    [Collection.mock(id: 178, title: "22 фильма о криминальной России")]
  }
}
