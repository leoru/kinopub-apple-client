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

/// Gate for the root UI. Content tabs must not mount until a Keychain token has
/// survived a refresh — otherwise a dead token paints Home for one frame, floods
/// every shelf with 401s, and each 401 tries to refresh again.
enum AuthPhase: Equatable {
  /// Keychain had a token; refresh is in flight. Show a splash, not Tabs.
  case resolving
  /// No usable session — device-activation screen.
  case signedOut
  /// Refresh succeeded (or a transient failure kept a still-plausible session).
  case signedIn
}

/// A class that manages the authentication state of the user.
@MainActor
final class AuthState: ObservableObject {
  @Published private(set) var phase: AuthPhase
  @Published var userState: UserState
  /// Back-compat for call sites that still read the flag; mirrors `phase == .signedOut`.
  @Published var shouldShowAuthentication: Bool
  /// True when this session began by exchanging a device code rather than by reviving a
  /// Keychain token — the moment kino.pub expects a full device profile, and the only
  /// one that re-registers it unconditionally.
  @Published private(set) var didActivateDevice = false

  private var authService: AuthorizationService
  private var accessTokenService: AccessTokenService
  private var refreshRetryTask: Task<Void, Never>?
  private var refreshRetryAttempt = 0
  /// Serializes refresh attempts — startup check, backoff retry and 401-triggered
  /// refreshes must never overlap.
  private var isRefreshing = false
  /// Set when a refresh was cut off mid-flight. **The next rejection cannot be trusted
  /// after one of those:** the cancelled request may well have reached kino.pub and
  /// rotated the refresh token there, in which case the following attempt presents a
  /// token the server has already retired and gets a 400 that says nothing about the
  /// session.
  private var lastRefreshWasCancelled = false

  /// Initializes the `AuthState` with the provided services.
  /// - Parameters:
  ///   - authService: The authorization service used for authentication.
  ///   - accessTokenService: The access token service used for managing access tokens.
  init(authService: AuthorizationService, accessTokenService: AccessTokenService) {
    self.authService = authService
    self.accessTokenService = accessTokenService
    // Never claim `.authorized` / show Tabs until `check()` finishes. A stale
    // Keychain token used to mount Home immediately, fire every shelf + sidebar
    // fetch, then tear it all down when refresh returned 400 — a self-DDoS.
    let hasToken = (accessTokenService.token() as AccessToken?) != nil
    if hasToken {
      self.phase = .resolving
      self.userState = .unauthorized
      self.shouldShowAuthentication = false
    } else {
      self.phase = .signedOut
      self.userState = .unauthorized
      self.shouldShowAuthentication = true
    }

    // A 401 from any content endpoint mid-session → one guarded refresh.
    NotificationCenter.default.addObserver(
      forName: .kinopubUnauthorizedResponse, object: nil, queue: .main
    ) { [weak self] _ in
      self?.handleUnauthorizedResponse() // Call to main actor-isolated instance method 'handleUnauthorizedResponse()' in a synchronous nonisolated context
    }
  }

  /// Checks the authentication state of the user.
  func check() async {
    Logger.app.debug("Start auth state checking...")
    guard let _: AccessToken = accessTokenService.token() else {
      markSignedOut(reason: "no token")
      return
    }

    // A re-run with the app already open (the root `.task` re-fires when the
    // hierarchy churns — the iOS player's orientation change used to tear it down
    // and back up under a film) must not bounce the UI to the splash: flipping
    // `.signedIn → .resolving` tears the tab shell down with the player route still
    // in its path, and the rebuild re-presented the player in a loop. Mid-session
    // expiry is the 401 observer's job, not this one's.
    guard phase != .signedIn else { return }

    // Stay on `.resolving` (splash) while we prove the token — do not flip to
    // signed-in optimistically.
    if phase != .resolving {
      phase = .resolving
      shouldShowAuthentication = false
      userState = .unauthorized
    }
    await refreshToken()
  }

  /// Device-activation screen got a token — enter the app. `activated` separates that
  /// from a token refresh, which reaches the same state without being a new device.
  func markSignedIn(activated: Bool = false) {
    refreshRetryTask?.cancel()
    refreshRetryTask = nil
    refreshRetryAttempt = 0
    if activated {
      didActivateDevice = true
    }
    phase = .signedIn
    userState = .authorized
    shouldShowAuthentication = false
    Logger.app.debug("Auth state: authorized")
  }

  /// A 401 from a content endpoint means the access token died mid-session. One
  /// refresh decides: success rotates quietly, rejection brings the activation
  /// screen, a network failure falls back to the scheduled retries.
  private func handleUnauthorizedResponse() {
    // Already signed out / still resolving / refresh in flight — swallow. In-flight
    // Home fetches after a fatal refresh used to log this line once per shelf.
    guard phase == .signedIn else { return }
    guard !isRefreshing else { return }
    guard let _: AccessToken = accessTokenService.token() else {
      markSignedOut(reason: "401 with empty keychain")
      return
    }
    Logger.app.info("Content endpoint answered 401 — refreshing the token")
    Task { await refreshToken() }
  }

  private func refreshToken() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    Logger.app.debug("Refreshing token...")
    do {
      // kino.pub rotates the refresh token on every call, so once a refresh has
      // started it must run to completion: a SwiftUI `.task` dying mid-request used
      // to cancel the URLSession task *after* the server had already rotated, the
      // new token never reached the Keychain, and the next refresh presented the
      // retired one → 400 → forced logout out of nowhere. The unstructured task is
      // not a child of the caller, so the caller's cancellation cannot reach the
      // request, and awaiting `value` is not itself cancellable.
      let job = Task { try await authService.refreshToken() }
      try await job.value
      lastRefreshWasCancelled = false
      markSignedIn()
    } catch let error as APIClientError where error.isFatalAuthError && !lastRefreshWasCancelled {
      // The backend explicitly rejected the refresh token — only now is the session
      // really over. Clear Keychain so the next launch does not revive a dead token.
      refreshRetryTask?.cancel()
      refreshRetryTask = nil
      authService.logout(userInitiated: false)
      markSignedOut(reason: "refresh rejected")
    } catch let error as APIClientError where error.isFatalAuthError {
      // Rejected, but right after a cancelled attempt — one grace round rather than
      // throwing the viewer at the activation screen on our own race.
      Logger.app.warning("Refresh rejected right after a cancelled one — keeping the session for one retry")
      lastRefreshWasCancelled = false
      markSignedIn()
      scheduleRefreshRetry()
    } catch {
      // Timeout / offline / unreachable host: keep the session. The Keychain token
      // may still be valid and every screen has its own error state — logging out
      // over a network hiccup just throws the user at the activation code screen.
      lastRefreshWasCancelled = Self.wasCancelled(error)
      Logger.app.warning("Token refresh failed transiently, keeping the session: \(error)")
      markSignedIn()
      scheduleRefreshRetry()
    }
  }

  /// A cancellation anywhere in the chain — the wrapper carries the `URLError` underneath.
  private static func wasCancelled(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    var stack: [NSError] = [error as NSError]
    while let next = stack.popLast() {
      if next.domain == NSURLErrorDomain, next.code == NSURLErrorCancelled { return true }
      stack.append(contentsOf: next.underlyingErrors.map { $0 as NSError })
    }
    return false
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
    markSignedOut(reason: "logout")
  }

  private func markSignedOut(reason: String) {
    didActivateDevice = false
    phase = .signedOut
    userState = .unauthorized
    shouldShowAuthentication = true
    Logger.app.info("Auth state: unauthorized (\(reason))")
  }
}
