//
//  VideoContentServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

final class VideoContentServiceImpl: VideoContentService {
  
  private var apiClient: APIClient
  
  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }
  
  func fetchItems() async throws -> [MediaItem] {
    let response = try await apiClient.performRequest(with: ItemsRequest(),
                                                      decodingType: PaginatedItemsResponse<MediaItem>.self)
    return response.items
  }
  
}
