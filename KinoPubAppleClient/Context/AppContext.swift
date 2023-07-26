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

typealias AppContextProtocol = AuthorizationServiceProvider & VideoContentServiceProvider & ConfigurationProvider

// MARK: - AppContext

struct AppContext: AppContextProtocol {
  
  var configuration: Configuration
  var authService: AuthorizationService
  var contentService: VideoContentService
  
  static let shared: AppContext = {
    let configuration = BundleConfiguration()
    let apiClient = makeApiClient(with: configuration.baseURL)
    return AppContext(configuration: configuration,
                      authService: AuthorizationServiceImpl(apiClient: apiClient, configuration: configuration),
                      contentService: VideoContentServiceImpl(apiClient: apiClient))
  }()
  
  private static func makeApiClient(with baseURL: String) -> APIClient {
    APIClient(baseUrl: baseURL,
              plugins: [
                CURLLoggingPlugin(),
                ResponseLoggingPlugin()
              ])
  }
}
