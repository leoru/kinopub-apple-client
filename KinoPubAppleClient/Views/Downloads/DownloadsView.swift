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
        List {
          activeDownloadsList
          downloadedFilesList
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color.KinoPub.background)
      }
      .navigationTitle("Downloads")
      .background(Color.KinoPub.background)
      .navigationDestination(for: DownloadsRoutes.self) { route in
        switch route {
        case .player(let item):
          PlayerView(manager: PlayerManager(mediaItem: item,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase))
        }
      }
      .onAppear(perform: {
        catalog.refresh()
      })
    }
    
  }
  
  var activeDownloadsList: some View {
    ForEach(catalog.activeDownloads, id: \.url) { download in
      NavigationLink(value: DownloadsRoutes.player(download.metadata)) {
        let binding = Binding<Float>(
          get: { download.progress },
          set: { _ in  })
        DownloadedItemView(mediaItem: download.metadata, progress: binding)
      }
    }
    .onDelete(perform: { indexSet in
      catalog.deleteActiveDownload(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }
  
  var downloadedFilesList: some View {
    ForEach(catalog.downloadedItems, id: \.originalURL) { fileInfo in
      NavigationLink(value: DownloadsRoutes.player(fileInfo.metadata)) {
        DownloadedItemView(mediaItem: fileInfo.metadata, progress: nil)
      }
    }
    .onDelete(perform: { indexSet in
      catalog.deleteDownloadedItem(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
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
