//
//  VideoContentService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

protocol VideoContentService {
  func fetchItems() async throws -> [MediaItem]
}

struct VideoContentServiceMock: VideoContentService {
  
  func fetchItems() async throws -> [MediaItem] {
    []
  }
  
}
