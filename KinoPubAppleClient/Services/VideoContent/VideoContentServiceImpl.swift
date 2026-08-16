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

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?, perPage: Int?) async throws -> PaginatedData<MediaItem> {
    let request = ShortcutItemsRequest(shortcut: shortcut, contentType: contentType, page: page, perPage: perPage)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func search(query: String?, page: Int?, perPage: Int?) async throws -> PaginatedData<MediaItem> {
    let request = SearchItemsRequest(contentType: nil, page: page, query: query, perPage: perPage)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: PaginatedData<MediaItem>.self)
    return response
  }

  func fetchDetails(for id: String, excludeLinks: Bool) async throws -> SingleItemData<MediaItem> {
    let request = ItemDetailsRequest(id: id, excludeLinks: excludeLinks)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: SingleItemData<MediaItem>.self)
    return response
  }

  func fetchMediaLinks(mediaId: Int) async throws -> MediaLinks {
    let request = MediaLinksRequest(mediaId: mediaId)
    return try await apiClient.performRequest(with: request, decodingType: MediaLinks.self)
  }

  func fetchSimilar(for id: String) async throws -> ArrayData<MediaItem> {
    let request = SimilarItemsRequest(id: id)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<MediaItem>.self)
    return response
  }

  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    let request = BookmarksRequest()
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ArrayData<Bookmark>.self)
    return response
  }
  
  func fetchBookmarkItems(id: String, page: Int?) async throws -> BookmarkFolderItemsData {
    let request = BookmarkItemsRequest(id: id, page: page)
    return try await apiClient.performRequest(with: request,
                                              decodingType: BookmarkFolderItemsData.self)
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

  func fetchHistory(page: Int?, perPage: Int = 20) async throws -> HistoryData {
    let request = HistoryRequest(page: page, perPage: perPage)
    return try await apiClient.performRequest(with: request,
                                              decodingType: HistoryData.self)
  }

  func fetchItems(filter: LibraryFilter, page: Int?) async throws -> PaginatedData<MediaItem> {
    let request = ItemsRequest(filter: filter, page: page)
    var response = try await apiClient.performRequest(
      with: request,
      decodingType: PaginatedData<MediaItem>.self
    )
    // Rating / quality / AC3 query params are silently ignored by /v1/items — filter locally.
    if filter.hasClientSideFacets {
      response.items = response.items.filter { filter.clientSideMatches($0) }
    }
    return response
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

  func fetchTVChannels() async throws -> [TVChannel] {
    let request = TVChannelsRequest()
    let response = try await apiClient.performRequest(
      with: request,
      decodingType: TVChannelsData.self
    )
    return response.channels
  }

}
