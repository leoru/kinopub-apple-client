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
