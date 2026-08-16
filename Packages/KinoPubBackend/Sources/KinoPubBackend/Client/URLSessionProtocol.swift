//
//  URLSessionProtocol.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation
import KinoPubLogging

public protocol URLSessionProtocol {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public class URLSessionImpl: URLSessionProtocol {
  let session: URLSession

  public init(session: URLSession) {
    self.session = session
  }

  /// Every kino.pub request passes through here, which is why the in-flight registry is
  /// hooked at this one point rather than threaded through call sites: no view model has
  /// to remember to report, and none can forget.
  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    let path = request.url?.path ?? ""
    let activity = NetworkActivity.begin(nameKey: Self.activityKey(forPath: path), detail: path)
    defer { NetworkActivity.end(activity) }
    do {
      return try await session.data(for: request)
    } catch {
      throw APIClientError.networkError(error)
    }
  }

  /// A localization key, because this ends up on the launch screen in front of a person
  /// waiting. Anything unmapped falls back to a plain "loading" rather than to the path:
  /// a new endpoint showing up as `/v1/items/…` on a user's TV is worse than saying less.
  /// The path still travels alongside it, for the debug overlay.
  static func activityKey(forPath path: String) -> String {
    switch true {
    case path.contains("/history"): return "Activity_History"
    case path.contains("/watching"): return "Activity_Watching"
    case path.contains("/bookmarks"): return "Activity_Bookmarks"
    case path.contains("/collections"): return "Activity_Collections"
    case path.contains("/device"): return "Activity_Device"
    case path.contains("/user"), path.contains("/oauth2"): return "Activity_Session"
    case path.contains("/items/search"): return "Activity_Search"
    case path.contains("/items"): return "Activity_Catalog"
    case path.contains("/types"), path.contains("/genres"), path.contains("/countries"):
      return "Activity_Sections"
    default: return "Activity_Network"
    }
  }
}
