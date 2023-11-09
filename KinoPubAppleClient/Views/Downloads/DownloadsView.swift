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
      ZStack {
        if catalog.isEmpty {
          emptyView
        } else {
          downloadsList
        }
      }
      .navigationTitle("Downloads")
      .background(Color.KinoPub.background)
      .navigationDestination(for: DownloadsRoutes.self) { route in
        switch route {
        case .player(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .media,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase))
        case .trailerPlayer(let item):
          PlayerView(manager: PlayerManager(playItem: item,
                                            watchMode: .trailer,
                                            downloadedFilesDatabase: appContext.downloadedFilesDatabase))
        }
      }
      .onAppear(perform: {
        catalog.refresh()
      })
    }
    
  }
  
  var downloadsList: some View {
    List {
      activeDownloadsList
      downloadedFilesList
    }
    .listStyle(.inset)
    .scrollContentBackground(.hidden)
    .background(Color.KinoPub.background)
  }
  
  var activeDownloadsList: some View {
    ForEach(catalog.activeDownloads, id: \.url) { download in
      NavigationLink(value: DownloadsRoutes.player(download.metadata)) {
        DownloadedItemView(mediaItem: download.metadata, progress: download.progress) { paused in
          catalog.toggle(download: download)
        }
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
        DownloadedItemView(mediaItem: fileInfo.metadata, progress: nil) { paused in
          
        }
      }
    }
    .onDelete(perform: { indexSet in
      catalog.deleteDownloadedItem(at: indexSet)
    })
    .listRowBackground(Color.KinoPub.background)
  }
  
  var emptyView: some View {
    VStack {
      Text("You don't have any downloads yet")
        .font(Font.KinoPub.subheader)
        .foregroundStyle(Color.KinoPub.text)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.KinoPub.background)
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
