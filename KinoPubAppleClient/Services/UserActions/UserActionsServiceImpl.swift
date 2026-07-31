//
//  UserActionsServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation
import KinoPubBackend

final class UserActionsServiceImpl: UserActionsService {

  private var apiClient: APIClient

  init(apiClient: APIClient) {
    self.apiClient = apiClient
  }

  func markWatch(id: Int, time: Int, video: Int?, season: Int?) async throws {
    let request = MarkTimeRequest(id: id, time: time, video: video, season: season)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }

  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> WatchData {
    let request = GetWatchingDataRequest(id: id, video: video, season: season)
    return try await apiClient.performRequest(with: request, decodingType: WatchData.self)
  }

  @discardableResult
  func toggleWatching(id: Int, video: Int?, season: Int?) async throws -> Int? {
    let request = ToggleWatchingRequest(id: id, video: video, season: season)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: ToggleWatchingResponse.self)
    return response.watched
  }

  func toggleWatchlist(id: Int) async throws {
    let request = ToggleWatchlistRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }

  func createBookmarkFolder(title: String) async throws -> Int {
    let request = CreateBookmarkFolderRequest(title: title)
    let response = try await apiClient.performRequest(with: request,
                                                      decodingType: CreateBookmarkFolderData.self)
    return response.folder.id
  }

  func removeBookmarkFolder(id: Int) async throws {
    let request = RemoveBookmarkFolderRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }

  func clearHistoryForItem(id: Int) async throws {
    let request = ClearHistoryForItemRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }

  func clearHistoryForMedia(id: Int) async throws {
    let request = ClearHistoryForMediaRequest(id: id)
    _ = try await apiClient.performRequest(with: request, decodingType: EmptyResponseData.self)
  }

  @discardableResult
  func vote(id: Int, like: Int) async throws -> VoteData {
    let request = VoteRequest(id: id, like: like)
    return try await apiClient.performRequest(with: request, decodingType: VoteData.self)
  }

}
