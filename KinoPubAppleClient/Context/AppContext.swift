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
& LocalWatchProgressProvider
& MediaLibraryProvider

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
  var downloadNotificationManager: DownloadNotificationManager
  var seasonDownloadManager: SeasonDownloadManager
  var hlsDownloadsStore: HLSDownloadsStore
  var hlsDownloadManager: HLSAssetDownloadManager
  var actionsService: UserActionsService
  var metadataService: MetadataService
  var kinopoiskKeyProvider: KinopoiskKeyProvider
  var contentStore: ContentStore
  var collectionsService: CollectionsService
  var deviceService: DeviceService
  var localProgressStore: LocalWatchProgressStore
  var libraryState: MediaLibraryStore

  static let shared: AppContext = {
    let configuration = BundleConfiguration()
    let keychainStorage = KeychainStorageImpl()
    let accessTokenService = AccessTokenServiceImpl(storage: keychainStorage)

    // Downloads (mp4 + resume control + iOS HLS). Non-TV only in the UI; Kit stays available.
    let fileSaver = FileSaver()
    let downloadedFilesDatabase = DownloadedFilesDatabase<DownloadMeta>(fileSaver: fileSaver)
    let downloadsControlDatabase = DownloadsControlDatabase<DownloadMeta>(fileSaver: fileSaver)
    let downloadManager = DownloadManager<DownloadMeta>(
      fileSaver: fileSaver,
      database: downloadedFilesDatabase,
      controlDatabase: downloadsControlDatabase
    )
    let downloadNotificationManager = DownloadNotificationManager()
    let seasonDownloadManager = SeasonDownloadManager(
      downloadManager: downloadManager,
      notifications: downloadNotificationManager
    )
    let hlsDownloadsStore = HLSDownloadsStore()
    let hlsDownloadManager = HLSAssetDownloadManager(
      store: hlsDownloadsStore,
      maxResolutionProvider: { StreamQuality.current.maxHeight }
    )
    hlsDownloadManager.onDownloadFinished = { [weak downloadNotificationManager] meta in
      downloadNotificationManager?.notifyFinished(title: meta.notificationTitle, identifier: "\(meta.id)")
    }
    hlsDownloadManager.onDownloadFailed = { [weak downloadNotificationManager] meta in
      downloadNotificationManager?.notifyFailed(title: meta.notificationTitle, identifier: "\(meta.id)")
    }
    // Deferred a tick: reattaching to a background AVAssetDownloadURLSession is an XPC round
    // trip to nsurlsessiond (~20-25ms measured, main-thread-only work since AVAssetDownloadURLSession
    // requires a main delegate queue here). Called synchronously this sat directly in front of
    // RootView's first frame, since `AppContext.shared` is resolved on the main thread before
    // any view renders. A paused/interrupted HLS download reattaching a few hundred ms later is
    // imperceptible; blocking every cold launch on it (even with zero downloads to restore) is not.
    Task { @MainActor in
      hlsDownloadManager.restorePendingDownloads()
    }
    downloadManager.onDownloadFinished = { [weak seasonDownloadManager, weak downloadNotificationManager] url, meta in
      let handledBySeason = seasonDownloadManager?.handleFinished(url: url) ?? false
      if !handledBySeason {
        downloadNotificationManager?.notifyFinished(title: meta.notificationTitle, identifier: "\(meta.id)")
      }
    }
    downloadManager.onDownloadFailed = { [weak downloadNotificationManager] _, meta, _ in
      downloadNotificationManager?.notifyFailed(title: meta.notificationTitle, identifier: "\(meta.id)")
    }

    let apiClient = makeApiClient(with: configuration.baseURL, accessTokenService: accessTokenService)

    let authService = AuthorizationServiceImpl(
      apiClient: apiClient,
      configuration: configuration,
      accessTokenService: accessTokenService
    )

    let metadataConfig = MetadataConfiguration(
      proxyBaseURL: configuration.tmdbProxyBaseURL.flatMap(URL.init(string:))
    )
    let kinopoiskKeyProvider = KinopoiskKeyProvider()
    let metadataService = MetadataService(sources: [
      TMDBSource(configuration: metadataConfig),
      KinopoiskSource(keyProvider: kinopoiskKeyProvider),
      KinopoiskProxySource()
    ])

    let contentStore = MainActor.assumeIsolated { ContentStore() }
    let localProgressStore = LocalWatchProgressStore()
    let libraryState = MediaLibraryStore(
      downloadManager: downloadManager,
      hlsDownloadManager: hlsDownloadManager,
      hlsStore: hlsDownloadsStore,
      downloadedFilesDatabase: downloadedFilesDatabase,
      progressStore: localProgressStore
    )

    return AppContext(
      configuration: configuration,
      authService: authService,
      contentService: VideoContentServiceImpl(apiClient: apiClient),
      accessTokenService: accessTokenService,
      userService: UserServiceImpl(apiClient: apiClient),
      keychainStorage: keychainStorage,
      fileSaver: fileSaver,
      downloadManager: downloadManager,
      downloadedFilesDatabase: downloadedFilesDatabase,
      downloadNotificationManager: downloadNotificationManager,
      seasonDownloadManager: seasonDownloadManager,
      hlsDownloadsStore: hlsDownloadsStore,
      hlsDownloadManager: hlsDownloadManager,
      actionsService: UserActionsServiceImpl(apiClient: apiClient),
      metadataService: metadataService,
      kinopoiskKeyProvider: kinopoiskKeyProvider,
      contentStore: contentStore,
      collectionsService: CollectionsServiceImpl(apiClient: apiClient),
      deviceService: DeviceServiceImpl(apiClient: apiClient),
      localProgressStore: localProgressStore,
      libraryState: libraryState
    )
  }()

  // MARK: - API Client building

  private static func makeApiClient(with baseURL: String, accessTokenService: AccessTokenService) -> APIClient {
    APIClient(
      baseUrl: baseURL,
      plugins: [
        // `CURLLoggingPlugin` is deliberately not here: it printed every request's
        // headers — `Authorization: Bearer …` included — into the system log, and the
        // Network log now renders cURL with the token redacted. The type is kept for
        // one-off local debugging, not for the default stack.
        ResponseLoggingPlugin(),
        UnauthorizedResponsePlugin(),
        AccessTokenPlugin(accessTokenService: accessTokenService)
      ],
      // Genres/countries only (see CacheableRequest). Personalized rows stay on ContentStore.
      cache: ResponseCache()
    )
  }
}
