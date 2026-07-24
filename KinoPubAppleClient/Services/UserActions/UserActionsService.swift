//
//  UserActionsService.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 11.11.2023.
//

import Foundation
import KinoPubBackend

protocol UserActionsService {
  func markWatch(id: Int, time: Int, video: Int?, season: Int?) async throws
  /// Toggles watched for a film (`video` usually 1) or one episode (`video` + `season`).
  /// Returns the new watched flag when the service sends one.
  @discardableResult
  func toggleWatching(id: Int, video: Int?, season: Int?) async throws -> Int?
  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> WatchData
  /// Removes a title from history / Continue Watching.
  func clearHistoryForItem(id: Int) async throws
  /// Removes one episode/video from history.
  func clearHistoryForMedia(id: Int) async throws
}

protocol UserActionsServiceProvider {
  var actionsService: UserActionsService { get set }
}

struct UserActionsServiceMock: UserActionsService {
  func markWatch(id: Int, time: Int, video: Int?, season: Int?) async throws {
  }

  func toggleWatching(id: Int, video: Int?, season: Int?) async throws -> Int? {
    nil
  }

  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> WatchData {
    WatchData.mock
  }

  func clearHistoryForItem(id: Int) async throws {
  }

  func clearHistoryForMedia(id: Int) async throws {
  }
}
