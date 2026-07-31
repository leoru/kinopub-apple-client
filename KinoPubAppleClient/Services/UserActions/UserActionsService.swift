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
  /// Subscribe / unsubscribe a series on the watchlist (`GET /v1/watching/togglewatchlist`).
  func toggleWatchlist(id: Int) async throws
  func createBookmarkFolder(title: String) async throws -> Int
  func removeBookmarkFolder(id: Int) async throws
  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> WatchData
  /// Removes a title from history / Continue Watching.
  func clearHistoryForItem(id: Int) async throws
  /// Removes one episode/video from history.
  func clearHistoryForMedia(id: Int) async throws
  /// Removes one season's history. DESIGN: season-rail action chrome TBD.
  func clearHistoryForSeason(id: Int) async throws
  /// Casts a thumbs vote (`like=1` up, `like=0` down). One-shot — `voted: false` means already voted.
  @discardableResult
  func vote(id: Int, like: Int) async throws -> VoteData
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

  func toggleWatchlist(id: Int) async throws {
  }

  func createBookmarkFolder(title: String) async throws -> Int {
    0
  }

  func removeBookmarkFolder(id: Int) async throws {
  }

  func fetchWatchMark(id: Int, video: Int?, season: Int?) async throws -> WatchData {
    WatchData.mock
  }

  func clearHistoryForItem(id: Int) async throws {
  }

  func clearHistoryForMedia(id: Int) async throws {
  }

  func clearHistoryForSeason(id: Int) async throws {
  }

  func vote(id: Int, like: Int) async throws -> VoteData {
    VoteData(voted: true, total: "1", positive: like == 1 ? "1" : "0", negative: like == 0 ? "1" : "0", rating: like == 1 ? 1 : -1)
  }
}
