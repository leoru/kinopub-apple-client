//
//  AppContext.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend

// MARK: - Env key

private struct AppContextKey: EnvironmentKey {
  static let defaultValue: AppContextProtocol = AppContext.shared
}

extension EnvironmentValues {
  var appContext: AppContextProtocol {
    get { self[AppContextKey.self] }
    set { self[AppContextKey.self] = newValue }
  }
}

// MARK: - AppContextProtocol

typealias AppContextProtocol = AuthorizationServiceProvider
& VideoContentServiceProvider
& ConfigurationProvider
& KeychainStorageProvider
& AccessTokenServiceProvider

// MARK: - AppContext

struct AppContext: AppContextProtocol {
  
  var configuration: Configuration
  var authService: AuthorizationService
  var contentService: VideoContentService
  var accessTokenService: AccessTokenService
  var keychainStorage: KeychainStorage
  
  static let shared: AppContext = {
    let configuration = BundleConfiguration()
    let keychainStorage = KeychainStorageImpl()
    let accessTokenService = AccessTokenServiceImpl(storage: keychainStorage)
    
    let apiClient = makeApiClient(with: configuration.baseURL, accessTokenService: accessTokenService)
    
    return AppContext(configuration: configuration,
                      authService: AuthorizationServiceImpl(apiClient: apiClient,
                                                            configuration: configuration,
                                                            accessTokenService: accessTokenService),
                      contentService: VideoContentServiceImpl(apiClient: apiClient),
                      accessTokenService: accessTokenService,
                      keychainStorage: keychainStorage)
  }()
  
  // MARK: - API Client building
  
  private static func makeApiClient(with baseURL: String, accessTokenService: AccessTokenService) -> APIClient {
    APIClient(baseUrl: baseURL,
              plugins: [
                CURLLoggingPlugin(),
                ResponseLoggingPlugin(),
                AccessTokenPlugin(accessTokenService: accessTokenService)
              ])
  }
}
