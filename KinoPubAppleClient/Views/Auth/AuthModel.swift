//
//  AuthModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubLogging
import OSLog
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Drives the device-activation screen: it asks for a code, polls for the token while the code is
/// on screen, and quietly replaces the code once it expires. Nothing here surfaces an error toast —
/// the screen has nowhere to go, so a failure just means "keep the spinner up and try again".
@MainActor
class AuthModel: ObservableObject {

  private var authService: AuthorizationService
  private var authState: AuthState

  /// The code the user types on the website. Empty until the first one arrives.
  @Published var deviceCode: String = ""
  /// Where to type it, as returned by the backend — shown as plain text on tvOS.
  @Published var verificationURL: String = ""
  /// A new code is on its way: the screen shows a spinner under the code.
  @Published var isRefreshing: Bool = true

  /// How long to wait before asking for a code again when the request itself failed.
  /// Doubles on every consecutive failure (capped at 30s) so an offline device does
  /// not hammer the API — and the log — every five seconds.
  private let retryInterval: TimeInterval = 5
  private let maxRetryInterval: TimeInterval = 30
  private var currentRetryInterval: TimeInterval = 5

  init(authService: AuthorizationService, authState: AuthState) {
    self.authService = authService
    self.authState = authState
  }

  /// Runs until the device is authorized. Driven from `.task`, so leaving the screen cancels it.
  func run() async {
    while !Task.isCancelled {
      isRefreshing = true

      guard let response = await requestDeviceCode() else {
        try? await Task.sleep(for: .seconds(currentRetryInterval))
        currentRetryInterval = min(currentRetryInterval * 2, maxRetryInterval)
        continue
      }

      currentRetryInterval = retryInterval
      deviceCode = response.userCode
      verificationURL = displayURL(from: response.verificationUri)
      isRefreshing = false

      if await pollForToken(with: response) {
        return
      }
    }
  }

  func openActivationURL() {
    guard let url = URL(string: verificationURL.hasPrefix("http") ? verificationURL : "https://\(verificationURL)") else {
      return
    }

    Logger.app.debug("open activation url: \(url)")

#if canImport(UIKit)
    UIApplication.shared.open(url)
#elseif os(macOS)
    NSWorkspace.shared.open(url)
#endif
  }

  private func requestDeviceCode() async -> VerificationResponse? {
    Logger.app.debug("Fetch device code...")
    do {
      let response = try await authService.fetchDeviceCode()
      Logger.app.debug("receive device code: \(response.userCode)")
      return response
    } catch {
      Logger.app.debug("failed to fetch device code: \(error)")
      return nil
    }
  }

  /// Polls until the user activates the code (`true`) or the code goes stale (`false`).
  /// Floor the server interval at 5s and honour `slow_down` so a pending device does
  /// not hammer `grant_type=device_token` every second (and flood the console).
  private func pollForToken(with response: VerificationResponse) async -> Bool {
    let expiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
    var interval = max(TimeInterval(response.interval), 5)

    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(interval))
      guard !Task.isCancelled else { return true }

      if Date() >= expiresAt {
        Logger.app.debug("device code expired, requesting a new one")
        return false
      }

      do {
        try await authService.fetchToken(by: response)
        authState.markSignedIn()
        Logger.app.debug("token requested")
        return true
      } catch let error as APIClientError where error.isAuthorizationPending {
        continue
      } catch let error as APIClientError where error.isSlowDown {
        interval = min(interval * 2, 30)
        Logger.app.debug("device poll slow_down — backing off to \(interval)s")
        continue
      } catch {
        Logger.app.debug("token request failed: \(error)")
        return false
      }
    }

    return true
  }

  /// `https://kino.pub/device` reads better on a TV as `kino.pub/device`.
  private func displayURL(from uri: String) -> String {
    uri
      .replacingOccurrences(of: "https://", with: "")
      .replacingOccurrences(of: "http://", with: "")
      .replacingOccurrences(of: "www.", with: "")
  }

}
