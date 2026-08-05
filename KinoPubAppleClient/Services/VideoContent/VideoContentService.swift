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
  func fetchSimilar(for id: String) async throws -> ArrayData<MediaItem>
  func fetchBookmarks() async throws -> ArrayData<Bookmark>
  func fetchBookmarkItems(id: String, page: Int?) async throws -> BookmarkFolderItemsData
  func fetchWatchingMovies() async throws -> ArrayData<WatchingItem>
  func fetchWatchingSerials(subscribedOnly: Bool) async throws -> ArrayData<WatchingItem>
  func fetchHistory(page: Int?) async throws -> HistoryData
  func fetchItems(filter: LibraryFilter, page: Int?) async throws -> PaginatedData<MediaItem>
  func fetchGenres(for type: MediaType?) async throws -> ArrayData<MediaGenre>
  func fetchCountries() async throws -> ArrayData<Country>
  func fetchItemFolders(itemId: Int) async throws -> ArrayData<Bookmark>
  func toggleBookmark(itemId: Int, folderId: Int) async throws
  /// Live sport / event channels — `GET /v1/tv`.
  func fetchTVChannels() async throws -> [TVChannel]
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

  func fetchSimilar(for id: String) async throws -> ArrayData<MediaItem> {
    // A short rail so MediaItem previews exercise the section instead of hiding it.
    return ArrayData.mock(data: [
      MediaItem.mock(id: 101),
      MediaItem.mock(id: 102),
      MediaItem.mock(id: 103),
    ])
  }

  func fetchBookmarks() async throws -> ArrayData<Bookmark> {
    return ArrayData.mock(data: [])
  }
  
  func fetchBookmarkItems(id: String, page: Int?) async throws -> BookmarkFolderItemsData {
    return BookmarkFolderItemsData(items: [])
  }

  func fetchWatchingMovies() async throws -> ArrayData<WatchingItem> {
    return ArrayData.mock(data: [])
  }

  func fetchWatchingSerials(subscribedOnly: Bool) async throws -> ArrayData<WatchingItem> {
    return ArrayData.mock(data: [])
  }

  func fetchHistory(page: Int?) async throws -> HistoryData {
    return HistoryData.mock(data: [])
  }

  func fetchItems(filter: LibraryFilter, page: Int?) async throws -> PaginatedData<MediaItem> {
    // Person shelves on the detail page need something non-empty so previews
    // exercise the rail instead of hiding it.
    if filter.person != nil {
      return PaginatedData.mock(data: [
        MediaItem.mock(id: 201),
        MediaItem.mock(id: 202),
        MediaItem.mock(id: 203),
      ])
    }
    return PaginatedData.mock(data: [])
  }

  func fetchGenres(for type: MediaType?) async throws -> ArrayData<MediaGenre> {
    return ArrayData.mock(data: [])
  }

  func fetchCountries() async throws -> ArrayData<Country> {
    return ArrayData.mock(data: [])
  }

  func fetchItemFolders(itemId: Int) async throws -> ArrayData<Bookmark> {
    return ArrayData.mock(data: [])
  }

  func toggleBookmark(itemId: Int, folderId: Int) async throws { }

  func fetchTVChannels() async throws -> [TVChannel] {
    []
  }

}
