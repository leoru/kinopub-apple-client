//
//  CollectionsServiceImpl.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

final class CollectionsServiceImpl: CollectionsService {

  private var apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func fetchCollections(page: Int?, sort: String?) async throws -> CollectionsData {
    let request = CollectionsRequest(page: page, sort: sort)
    return try await apiClient.performRequest(with: request, decodingType: CollectionsData.self)
  }

  /// 🔎 Captured from the PWA on `api2/v1.1`; this asks our own `/v1` for the same
  /// path. If that host does not have it the call throws and the detail page simply
  /// shows no collection shelves — the log line is what tells us which it was.
  func fetchCollections(forItem id: Int) async throws -> [Collection] {
    let request = ItemCollectionsRequest(itemId: id)
    // The captured payload answers `items`, the listing answers `collections`, and
    // `CollectionsData` already accepts either.
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: CollectionsData.self)
    return response.collections
  }

  func fetchCollection(id: Int) async throws -> (Collection, [MediaItem]) {
    let request = CollectionViewRequest(id: id)
    let response = try await apiClient.performRequest(
      with: request,
      decodingType: CollectionItemsData.self
    )
    let collection = response.collection ?? Collection.mock(id: id)
    return (collection, response.items)
  }
}
