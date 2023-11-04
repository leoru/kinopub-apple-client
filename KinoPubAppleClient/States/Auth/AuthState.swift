
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
  @Published var userState: UserState = .unauthorized
  @Published var shouldShowAuthentication: Bool = false
  
  private var authService: AuthorizationService
  private var accessTokenService: AccessTokenService
  
  /// Initializes the `AuthState` with the provided services.
  /// - Parameters:
  ///   - authService: The authorization service used for authentication.
  ///   - accessTokenService: The access token service used for managing access tokens.
  init(authService: AuthorizationService, accessTokenService: AccessTokenService) {
    self.authService = authService
    self.accessTokenService = accessTokenService
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
  
  private func refreshToken() async {
    Logger.app.debug("Refreshing token...")
    do {
      try await authService.refreshToken()
      userState = .authorized
      shouldShowAuthentication = false
      Logger.app.debug("Auth state: authorized")
    } catch {
      await MainActor.run {
        userState = .unauthorized
        shouldShowAuthentication = true
        Logger.app.debug("Failed to refresh token, auth state: unauthorized")
      }
    }
  }
  
  /// Logs out the user.
  func logout() {
    authService.logout()
    userState = .unauthorized
    shouldShowAuthentication = true
  }
}
