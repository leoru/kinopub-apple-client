//
//  VideoContentService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

protocol VideoContentService {
  func fetchItems() async throws -> PaginatedData<MediaItem>
}

protocol VideoContentServiceProvider {
  var contentService: VideoContentService { get set }
}

struct VideoContentServiceMock: VideoContentService {
  
  func fetchItems() async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }
  
}

