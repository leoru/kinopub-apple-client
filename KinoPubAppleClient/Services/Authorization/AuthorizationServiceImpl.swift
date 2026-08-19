//
//  AuthorizationServiceImpl.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import KinoPubBackend

final class AuthorizationServiceImpl: AuthorizationService {
  
  private var apiClient: APIClient
  private var configuration: Configuration
  private var accessTokenService: AccessTokenService

  init(apiClient: APIClient, configuration: Configuration, accessTokenService: AccessTokenService) {
    self.apiClient = apiClient
    self.configuration = configuration
    self.accessTokenService = accessTokenService
  }

  func fetchDeviceCode() async throws -> VerificationResponse {
    let request = DeviceCodeRequest(grantType: .deviceCode, clientID: configuration.clientID, clientSecret: configuration.clientSecret)
    return try await apiClient.performRequest(with: request, decodingType: VerificationResponse.self)
  }

  func fetchToken(by verification: VerificationResponse) async throws {
    let request = DeviceCodeRequest(grantType: .deviceToken, clientID: configuration.clientID, clientSecret: configuration.clientSecret, code: verification.code)
    let token = try await apiClient.performRequest(with: request, decodingType: AccessToken.self)
    accessTokenService.set(token: token)
  }

  func refreshToken() async throws {
    guard let token: AccessToken = accessTokenService.token() else {
      return
    }

    let request = RefreshTokenRequest(clientID: configuration.clientID,
                                      clientSecret: configuration.clientSecret,
                                      refreshToken: token.refreshToken)
    do {
      let newToken = try await apiClient.performRequest(with: request, decodingType: AccessToken.self)
      accessTokenService.set(token: newToken)
    } catch {
#if DEBUG && (targetEnvironment(simulator) || os(macOS))
      // kino.pub rotates refresh tokens: refreshing invalidates the token that was used.
      // Debug builds share one session file, so a second build refreshing a minute later
      // presents a token the backend already retired and gets a 400 — even though the
      // session is perfectly alive under the *new* token. Adopt whatever the shared file
      // holds now before treating this as a dead session.
      if let shared = DevSessionMirror.load(), shared.refreshToken != token.refreshToken {
        accessTokenService.set(token: shared)
        return
      }
#endif
      throw error
    }
  }

  func logout() {
    logout(userInitiated: true)
  }

  func logout(userInitiated: Bool) {
    accessTokenService.clear(userInitiated: userInitiated)
    BookmarkMembershipStore.shared.clear()
    // Folder names outlive a session on disk, so they have to go with the account.
    Task { @MainActor in BookmarkFoldersStore.shared.clear() }
    AppContext.shared.libraryState.clear()
    // The device record belonged to the account we just left — the next activation has
    // to register its identity and streaming profile from scratch.
    DeviceProfileRegistry.reset()
    // Do NOT clear ResponseCache — we only cache immutable reference lists
    // (genres/countries). Those never change per account on kino.pub.
  }

}
