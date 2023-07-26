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
  
  init(apiClient: APIClient, configuration: Configuration) {
    self.apiClient = apiClient
    self.configuration = configuration
  }
  
  func fetchDeviceCode() async throws -> VerificationResponse {
    let request = DeviceCodeRequest(clientID: configuration.clientID, clientSecret: configuration.clientSecret)
    return try await apiClient.performRequest(with: request, decodingType: VerificationResponse.self)
  }
  
  func fetchToken(by verification: VerificationResponse) async throws -> TokenResponse {
    let request = DeviceCodeRequest(clientID: configuration.clientID, clientSecret: configuration.clientSecret, code: verification.code)
    return try await apiClient.performRequest(with: request, decodingType: TokenResponse.self)
  }
  
  func refreshToken() async throws -> TokenResponse {
    let request = RefreshTokenRequest(clientID: configuration.clientID, clientSecret: configuration.clientSecret, refreshToken: "")
    return try await apiClient.performRequest(with: request, decodingType: TokenResponse.self)
  }

}
