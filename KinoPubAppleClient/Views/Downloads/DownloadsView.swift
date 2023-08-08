//
//  DownloadsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//

import SwiftUI
import KinoPubBackend
import KinoPubKit

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
      VStack {
        ScrollView {
          activeDownloadsList
          downloadedFilesList
        }
      }
      .navigationTitle("Downloads")
      .background(Color.KinoPub.background)
      .navigationDestination(for: DownloadsRoutes.self) { route in
        switch route {
        case .player(let item):
          PlayerView(manager: PlayerManager(mediaItem: item))
        }
      }
      .onAppear(perform: {
        catalog.refresh()
      })
    }
    
  }
  
  var activeDownloadsList: some View {
    VStack(alignment: .leading) {
      ForEach(catalog.activeDownloads, id: \.url) { download in
        NavigationLink(value: DownloadsRoutes.player(download.metadata)) {
          let binding = Binding<Float>(
            get: { download.progress },
            set: { _ in  })
          DownloadedItemView(mediaItem: download.metadata, progress: binding)
        }
      }
    }
  }
  
  var downloadedFilesList: some View {
    VStack(alignment: .leading) {
      ForEach(catalog.downloadedItems, id: \.originalURL) { fileInfo in
        NavigationLink(value: DownloadsRoutes.player(fileInfo.metadata)) {
          DownloadedItemView(mediaItem: fileInfo.metadata, progress: nil)
        }
      }
    }
  }
}

struct DownloadsView_Previews: PreviewProvider {
  static var previews: some View {
    
    let database = DownloadedFilesDatabase<MediaItem>(fileSaver: FileSaver())
    
    let downloadManager = DownloadManager<MediaItem>(fileSaver: FileSaver(), database: database)
    
    DownloadsView(catalog: DownloadsCatalog(downloadsDatabase: database,
                                            downloadManager: downloadManager))
  }
}
