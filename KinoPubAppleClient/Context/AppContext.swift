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
import KinoPubMetadata

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
& MetadataServiceProvider
& KinopoiskKeyProviderProvider
& ContentStoreProvider
& CollectionsServiceProvider
& DeviceServiceProvider

protocol MetadataServiceProvider {
  var metadataService: MetadataService { get }
}

protocol ContentStoreProvider {
  var contentStore: ContentStore { get }
}

protocol KinopoiskKeyProviderProvider {
  var kinopoiskKeyProvider: KinopoiskKeyProvider { get }
}

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
  var metadataService: MetadataService
  var kinopoiskKeyProvider: KinopoiskKeyProvider
  var contentStore: ContentStore
  var collectionsService: CollectionsService
  var deviceService: DeviceService

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

    let metadataConfig = MetadataConfiguration(
      proxyBaseURL: configuration.tmdbProxyBaseURL.flatMap(URL.init(string:))
    )
    let kinopoiskKeyProvider = KinopoiskKeyProvider()
    // Keyed Kinopoisk Unofficial first (awards + richer when the user pasted a key);
    // keyless kpapp.link proxy always-on so facts/stills/reviews work without Settings.
    let metadataService = MetadataService(sources: [
      TMDBSource(configuration: metadataConfig),
      KinopoiskSource(keyProvider: kinopoiskKeyProvider),
      KinopoiskProxySource()
    ])

    // `AppContext.shared` is only ever first-accessed from the main thread (app
    // launch / view inits) — this only exists because `static let` initializers
    // aren't otherwise allowed to touch a `@MainActor` type.
    let contentStore = MainActor.assumeIsolated { ContentStore() }

    return AppContext(configuration: configuration,
                      authService: authService,
                      contentService: VideoContentServiceImpl(apiClient: apiClient),
                      accessTokenService: accessTokenService,
                      userService: UserServiceImpl(apiClient: apiClient),
                      keychainStorage: keychainStorage,
                      fileSaver: fileSaver,
                      downloadManager: downloadManager,
                      downloadedFilesDatabase: downloadedFilesDatabase,
                      actionsService: UserActionsServiceImpl(apiClient: apiClient),
                      metadataService: metadataService,
                      kinopoiskKeyProvider: kinopoiskKeyProvider,
                      contentStore: contentStore,
                      collectionsService: CollectionsServiceImpl(apiClient: apiClient),
                      deviceService: DeviceServiceImpl(apiClient: apiClient))
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
