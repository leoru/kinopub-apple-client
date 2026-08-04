//
//  DownloadsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubBackend
import KinoPubKit
import KinoPubUI

struct DownloadsView: View {
  
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var catalog: DownloadsCatalog
  
  init(catalog: @autoclosure @escaping () -> DownloadsCatalog) {
    _catalog = StateObject(wrappedValue: catalog())
  }
  
  var body: some View {
    NavigationStack(path: $navigationState.downloadsRoutes) {
      ZStack {
        if catalog.isEmpty {
          emptyView
        } else {
          downloadsList
        }
      }
      .platformNavigationTitle("Downloads")
      .background(Color.KinoPub.background)
      .navigationDestination(for: Route.self) { route in
        RouteDestination(route: route, linkProvider: AppRoutesLinkProvider())
      }
      .onAppear(perform: {
        catalog.refresh()
      })
    }
    .navigationStackActive(for: .downloads, selected: navigationState.selectedTab)
  }
  
  var downloadsList: some View {
    List {
      activeDownloadsList
      downloadedFilesList
    }
#if !os(tvOS)
    .listStyle(.inset)
    .scrollContentBackground(.hidden)
#endif
    .background(Color.KinoPub.background)
  }
  
  var activeDownloadsList: some View {
    ForEach(catalog.activeDownloads, id: \.url) { download in
      PlayerLink(route: DownloadsRoutes.player(download.metadata), item: download.metadata, mode: .media) {
        DownloadedItemView(mediaItem: download.metadata, progress: download.progress) { paused in
          catalog.toggle(download: download)
        }
      }
#if os(macOS)
      .buttonStyle(.plain)
#endif
    }
    .onDelete(perform: { indexSet in
      catalog.deleteActiveDownload(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }
  
  var downloadedFilesList: some View {
    ForEach(catalog.downloadedItems, id: \.originalURL) { fileInfo in
      PlayerLink(route: DownloadsRoutes.player(fileInfo.metadata), item: fileInfo.metadata, mode: .media) {
        DownloadedItemView(mediaItem: fileInfo.metadata, progress: nil) { paused in

        }
      }
#if os(macOS)
      .buttonStyle(.plain)
#endif
    }
    .onDelete(perform: { indexSet in
      catalog.deleteDownloadedItem(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }
  
  /// Downloads is a local-only feature — nothing here can fail to "load", so this
  /// is always an empty state, never an error one. Same `UnavailableView` as
  /// everywhere else, with a way back to something to watch.
  var emptyView: some View {
    UnavailableView(title: "You don't have any downloads yet",
                    systemImage: "arrow.down.circle",
                    message: "Movies and shows you download will appear here.".localized,
                    retryTitle: "Continue Watching",
                    onRetry: {
      navigationState.selectedTab = .home
    })
  }
}

struct DownloadsView_Previews: PreviewProvider {
  static var previews: some View {
    
    let database = DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())
    
    let downloadManager = DownloadManager<DownloadMeta>(fileSaver: FileSaver(), database: database)
    
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: database,
                                            downloadManager: downloadManager))
  }
}
