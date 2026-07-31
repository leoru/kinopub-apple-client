//
//  CollectionsService.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

protocol CollectionsService {
  func fetchCollections(page: Int?, sort: String?) async throws -> CollectionsData
  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem])
}

protocol CollectionsServiceProvider {
  var collectionsService: CollectionsService { get set }
}

struct CollectionsServiceMock: CollectionsService {

  func fetchCollections(page: Int?, sort: String?) async throws -> CollectionsData {
    .mock(data: [
      Collection.mock(id: 1, title: "Mock Collection")
    ])
  }

  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem]) {
    (Collection.mock(id: id), [MediaItem.mock(id: 101), MediaItem.mock(id: 102)])
  }
}
