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
  
  func fetchToken(by verification: VerificationResponse) async throws -> AccessToken {
    let request = DeviceCodeRequest(grantType: .deviceToken, clientID: configuration.clientID, clientSecret: configuration.clientSecret, code: verification.code)
    return try await apiClient.performRequest(with: request, decodingType: AccessToken.self)
  }
  
  func refreshToken() async throws -> AccessToken {
    let request = RefreshTokenRequest(clientID: configuration.clientID, clientSecret: configuration.clientSecret, refreshToken: "")
    return try await apiClient.performRequest(with: request, decodingType: AccessToken.self)
  }

}
