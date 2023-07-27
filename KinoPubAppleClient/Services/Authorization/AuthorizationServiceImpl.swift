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
    let newToken = try await apiClient.performRequest(with: request, decodingType: AccessToken.self)
    accessTokenService.set(token: newToken)
  }

}
