//
//  UnauthorizedResponsePlugin.swift
//  KinoPubAppleClient
//

import Foundation
import KinoPubBackend

extension Notification.Name {
  /// Posted when any content (non-oauth) endpoint answers 401 — the access token
  /// died mid-session. `AuthState` listens and runs a guarded token refresh.
  static let kinopubUnauthorizedResponse = Notification.Name("kinopubUnauthorizedResponse")
}

/// Watches for 401s from content endpoints and broadcasts them. OAuth endpoints are
/// excluded: the refresh/device flows handle their own failures, and a device-code
/// screen that isn't authorized yet would otherwise spam refresh attempts.
final class UnauthorizedResponsePlugin: APIClientPlugin {

  init() {}

  func prepare(_ request: URLRequest) -> URLRequest {
    request
  }

  func willSend(_ request: URLRequest) {}

  func didReceive(_ response: URLResponse, data: Data?) {
    guard let http = response as? HTTPURLResponse,
          http.statusCode == 401,
          http.url?.path.contains("oauth2") == false else { return }
    NotificationCenter.default.post(name: .kinopubUnauthorizedResponse, object: nil)
  }
}
