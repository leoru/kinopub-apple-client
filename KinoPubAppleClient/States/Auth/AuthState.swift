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

enum UserState {
  case unauthorized
  case authorized
}

@MainActor
final class AuthState: ObservableObject {
  @Published var userState: UserState = .unauthorized
  @Published var shouldShowAuthentication: Bool = false

  private var authService: AuthorizationService
  private var accessTokenService: AccessTokenService

  init(authService: AuthorizationService, accessTokenService: AccessTokenService) {
    self.authService = authService
    self.accessTokenService = accessTokenService
  }

  func check() {
    Logger.app.debug("start auth state checking...")
    guard let _: AccessToken = accessTokenService.token() else {
      userState = .unauthorized
      shouldShowAuthentication = true
      Logger.app.debug("auth state: unauthorized")
      return
    }

    refreshToken()
  }

  func refreshToken() {
    Logger.app.debug("refreshing token...")
    Task {
      do {
        try await authService.refreshToken()
        userState = .authorized
        shouldShowAuthentication = false
        Logger.app.debug("auth state: authorized")
      } catch {
        await MainActor.run {
          userState = .unauthorized
          shouldShowAuthentication = true
          Logger.app.debug("failed to refresh token, auth state: unauthorized")
        }
      }
    }
  }

}
