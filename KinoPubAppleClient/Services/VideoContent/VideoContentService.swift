//
//  VideoContentService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

protocol VideoContentService {
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?, perPage: Int?) async throws -> PaginatedData<MediaItem>
  func search(query: String?, page: Int?, perPage: Int?) async throws -> PaginatedData<MediaItem>
  /// - Parameter excludeLinks: `nolinks=1` — details without video links. Only for
  ///   callers that will resolve links per media with `fetchMediaLinks(mediaId:)`.
  func fetchDetails(for id: String, excludeLinks: Bool) async throws -> SingleItemData<MediaItem>
  /// Files + subtitles of one media (an episode's own id, or a film's video id).
  func fetchMediaLinks(mediaId: Int) async throws -> MediaLinks
  func fetchSimilar(for id: String) async throws -> ArrayData<MediaItem>
  func fetchBookmarks() async throws -> ArrayData<Bookmark>
  func fetchBookmarkItems(id: String, page: Int?) async throws -> BookmarkFolderItemsData
  func fetchWatchingMovies() async throws -> ArrayData<WatchingItem>
  func fetchWatchingSerials(subscribedOnly: Bool) async throws -> ArrayData<WatchingItem>
  /// - Parameter perPage: raw history *entries*, not cards. History is one entry per
  ///   play, so a page of 20 collapses to far fewer titles — see `LibrarySectionCatalog`.
  func fetchHistory(page: Int?, perPage: Int) async throws -> HistoryData
  func fetchItems(filter: LibraryFilter, page: Int?) async throws -> PaginatedData<MediaItem>
  func fetchGenres(for type: MediaType?) async throws -> ArrayData<MediaGenre>
  func fetchCountries() async throws -> ArrayData<Country>
  func fetchItemFolders(itemId: Int) async throws -> ArrayData<Bookmark>
  func toggleBookmark(itemId: Int, folderId: Int) async throws
  /// Live sport / event channels — `GET /v1/tv`.
  func fetchTVChannels() async throws -> [TVChannel]
}

extension VideoContentService {
  /// Back-compat overloads for callers that don't tune page size. Home rails, the
  /// background `StreamSurvey`, and the search screen keep the terse call and get the
  /// server's default page; only the full-screen grids in `MediaCatalog` pass an
  /// explicit `perPage` (see `CatalogPageSize`).
  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?) async throws -> PaginatedData<MediaItem> {
    try await fetch(shortcut: shortcut, contentType: contentType, page: page, perPage: nil)
  }

  func search(query: String?, page: Int?) async throws -> PaginatedData<MediaItem> {
    try await search(query: query, page: page, perPage: nil)
  }

  /// Details with links, which is what every caller that plays straight from the payload
  /// wants. The detail page is the exception and asks for `excludeLinks: true`.
  func fetchDetails(for id: String) async throws -> SingleItemData<MediaItem> {
    try await fetchDetails(for: id, excludeLinks: false)
  }
}

protocol VideoContentServiceProvider {
  var contentService: VideoContentService { get set }
}

struct VideoContentServiceMock: VideoContentService {

  func fetch(shortcut: MediaShortcut, contentType: MediaType, page: Int?, perPage: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func search(query: String?, page: Int?, perPage: Int?) async throws -> PaginatedData<MediaItem> {
    return PaginatedData.mock(data: [])
  }

  func fetchDetails(for id: String, excludeLinks: Bool) async throws -> SingleItemData<MediaItem> {
    return SingleItemData.mock(data: MediaItem.mock())
  }

  func fetchMediaLinks(mediaId: Int) async throws -> MediaLinks {
    return MediaLinks(files: [])
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

  func fetchHistory(page: Int?, perPage: Int = 20) async throws -> HistoryData {
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
