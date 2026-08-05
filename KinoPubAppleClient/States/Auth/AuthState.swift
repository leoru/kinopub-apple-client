
//
//  AuthState.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 3.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

/// Represents the state of the user's authentication.
enum UserState {
  case unauthorized
  case authorized
}

/// A class that manages the authentication state of the user.
@MainActor
final class AuthState: ObservableObject {
  @Published var userState: UserState
  @Published var shouldShowAuthentication: Bool
  
  private var authService: AuthorizationService
  private var accessTokenService: AccessTokenService
  private var refreshRetryTask: Task<Void, Never>?
  private var refreshRetryAttempt = 0
  /// Serializes refresh attempts — startup check, backoff retry and 401-triggered
  /// refreshes must never overlap.
  private var isRefreshing = false

  /// Initializes the `AuthState` with the provided services.
  /// - Parameters:
  ///   - authService: The authorization service used for authentication.
  ///   - accessTokenService: The access token service used for managing access tokens.
  init(authService: AuthorizationService, accessTokenService: AccessTokenService) {
    self.authService = authService
    self.accessTokenService = accessTokenService
    // Keychain read is sync. Without a token, show auth immediately — otherwise
    // `TabsNavigationView` mounts for one frame, fires 401s, then tears down under
    // animation and UIKit TabView asserts ("No view controller matches UITabBarItem").
    let hasToken = (accessTokenService.token() as AccessToken?) != nil
    self.userState = hasToken ? .authorized : .unauthorized
    self.shouldShowAuthentication = !hasToken

    // A 401 from any content endpoint mid-session → one guarded refresh.
    NotificationCenter.default.addObserver(
      forName: .kinopubUnauthorizedResponse, object: nil, queue: .main
    ) { [weak self] _ in
      self?.handleUnauthorizedResponse()
    }
  }

  /// Checks the authentication state of the user.
  func check() async {
    Logger.app.debug("Start auth state checking...")
    guard let _: AccessToken = accessTokenService.token() else {
      userState = .unauthorized
      shouldShowAuthentication = true
      Logger.app.debug("Auth state: unauthorized")
      return
    }

    await refreshToken()
  }

  /// A 401 from a content endpoint means the access token died mid-session. One
  /// refresh decides: success rotates quietly, rejection brings the activation
  /// screen, a network failure falls back to the scheduled retries.
  private func handleUnauthorizedResponse() {
    // A wave of 401s from every screen must not become a wave of refresh attempts
    // (or log lines) — one in flight is enough.
    guard !isRefreshing else { return }
    Logger.app.info("Content endpoint answered 401 — refreshing the token")
    guard let _: AccessToken = accessTokenService.token() else {
      userState = .unauthorized
      shouldShowAuthentication = true
      return
    }
    Task { await refreshToken() }
  }

  private func refreshToken() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    Logger.app.debug("Refreshing token...")
    do {
      try await authService.refreshToken()
      refreshRetryAttempt = 0
      userState = .authorized
      shouldShowAuthentication = false
      Logger.app.debug("Auth state: authorized")
    } catch let error as APIClientError where error.isFatalAuthError {
      // The backend explicitly rejected the refresh token — only now is the session
      // really over. Clear Keychain so the next launch does not revive a dead token.
      refreshRetryTask?.cancel()
      refreshRetryTask = nil
      authService.logout()
      userState = .unauthorized
      shouldShowAuthentication = true
      Logger.app.info("Refresh token rejected, auth state: unauthorized")
    } catch {
      // Timeout / offline / unreachable host: keep the session. The Keychain token
      // may still be valid and every screen has its own error state — logging out
      // over a network hiccup just throws the user at the activation code screen.
      userState = .authorized
      shouldShowAuthentication = false
      Logger.app.warning("Token refresh failed transiently, keeping the session: \(error)")
      scheduleRefreshRetry()
    }
  }

  /// Retries a failed refresh with backoff (5s → 10s → 20s → … capped at 2 min) so a
  /// network blip at launch resolves itself once connectivity returns.
  private func scheduleRefreshRetry() {
    refreshRetryTask?.cancel()
    let delay = min(5 * pow(2.0, Double(refreshRetryAttempt)), 120)
    refreshRetryAttempt += 1
    refreshRetryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(delay))
      guard !Task.isCancelled, let self else { return }
      await self.refreshToken()
    }
  }

  /// Logs out the user.
  func logout() {
    refreshRetryTask?.cancel()
    refreshRetryTask = nil
    authService.logout()
    userState = .unauthorized
    shouldShowAuthentication = true
  }
}
