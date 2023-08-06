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

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = ShortcutItemsRequest(shortcut: shortcut, contentType: contentType, page: page)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = SearchItemsRequest(contentType: nil, page: page, query: query)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    let request = ItemDetailsRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: SingleItemData<MediaItem>.self)
    return response
  }
  
  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    let request = BookmarksRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<Bookmark>.self)
    return response
  }
  
  func fetchBookmarkItems(id: String) async throws -> ArrayData<MediaItem> {
    let request = BookmarkItemsRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<MediaItem>.self)
    return response
  }

}
