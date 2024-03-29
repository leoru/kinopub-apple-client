//
//  AppContext.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation
import SwiftUI
import KinoPubBackend
import KinoPubKit

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
& DownloadManagerProvider
& DownloadedFilesDatabaseProvider
& FileSaverProvider
& UserServiceProvider
& UserActionsServiceProvider

// MARK: - AppContext

struct AppContext: AppContextProtocol {
  
  var configuration: Configuration
  var authService: AuthorizationService
  var contentService: VideoContentService
  var accessTokenService: AccessTokenService
  var userService: UserService
  var keychainStorage: KeychainStorage
  var fileSaver: FileSaving
  var downloadManager: DownloadManager<DownloadMeta>
  var downloadedFilesDatabase: DownloadedFilesDatabase<DownloadMeta>
  var actionsService: UserActionsService
  
  static let shared: AppContext = {
    let configuration = BundleConfiguration()
    let keychainStorage = KeychainStorageImpl()
    let accessTokenService = AccessTokenServiceImpl(storage: keychainStorage)
    
    // Downloads
    
    let fileSaver = FileSaver()
    let downloadedFilesDatabase = DownloadedFilesDatabase<DownloadMeta>(fileSaver: fileSaver)
    let downloadManager = DownloadManager<DownloadMeta>(fileSaver: fileSaver, database: downloadedFilesDatabase)
    // Api Client
    let apiClient = makeApiClient(with: configuration.baseURL, accessTokenService: accessTokenService)
    
    let authService = AuthorizationServiceImpl(apiClient: apiClient,
                                               configuration: configuration,
                                               accessTokenService: accessTokenService)
    return AppContext(configuration: configuration,
                      authService: authService,
                      contentService: VideoContentServiceImpl(apiClient: apiClient),
                      accessTokenService: accessTokenService,
                      userService: UserServiceImpl(apiClient: apiClient),
                      keychainStorage: keychainStorage,
                      fileSaver: fileSaver,
                      downloadManager: downloadManager,
                      downloadedFilesDatabase: downloadedFilesDatabase,
                      actionsService: UserActionsServiceImpl(apiClient: apiClient))
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
