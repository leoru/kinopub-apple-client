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

  func fetchWatchingMovies() async throws -> ArrayData<WatchingItem> {
    let request = WatchingMoviesRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<WatchingItem>.self)
    return response
  }

  func fetchWatchingSerials(subscribedOnly: Bool) async throws -> ArrayData<WatchingItem> {
    let request = WatchingSerialsRequest(subscribedOnly: subscribedOnly)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<WatchingItem>.self)
    return response
  }

  func fetchHistory() async throws -> HistoryData {
    let request = HistoryRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: HistoryData.self)
    return response
  }

  func fetchItems(filter: LibraryFilter, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = ItemsRequest(filter: filter, page: page)
    return try await apiClient.performRequest(with: request,
                                              decodingType: PaginatedData<MediaItem>.self)
  }

  func fetchGenres(for type: MediaType?) async throws -> ArrayData<MediaGenre> {
    let request = GenresRequest(contentType: type)
    return try await apiClient.performRequest(with: request,
                                              decodingType: ArrayData<MediaGenre>.self)
  }

  func fetchCountries() async throws -> ArrayData<Country> {
    let request = CountriesRequest()
    return try await apiClient.performRequest(with: request,
                                              decodingType: ArrayData<Country>.self)
  }

  func fetchItemFolders(itemId: Int) async throws -> ArrayData<Bookmark> {
    let request = ItemFoldersRequest(itemId: itemId)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<Bookmark>.self)
    return response
  }

  func toggleBookmark(itemId: Int, folderId: Int) async throws {
    let request = ToggleBookmarkRequest(itemId: itemId, folderId: folderId)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }

}
