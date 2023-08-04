//
//  VideoContentService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

protocol VideoContentService {
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem>
  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem>
  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem>
}

protocol VideoContentServiceProvider {
  var contentService: VideoContentService { get set }
}

struct VideoContentServiceMock: VideoContentService {

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    return SingleItemData.mock(data: MediaItem.mock())
  }

}
