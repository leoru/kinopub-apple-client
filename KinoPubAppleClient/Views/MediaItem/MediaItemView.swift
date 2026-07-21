//
//  MediaItemView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation
import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubKit

struct MediaItemView: View {

  @EnvironmentObject var errorHandler: ErrorHandler
  @StateObject private var itemModel: MediaItemModel

  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _itemModel = StateObject(wrappedValue: model())
  }

  var body: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
        MediaItemHeroView(mediaItem: itemModel.mediaItem,
                          isSkeleton: !itemModel.itemLoaded,
                          linkProvider: itemModel.linkProvider,
                          isWatched: itemModel.isWatched,
                          isBookmarked: itemModel.isBookmarked,
                          folders: itemModel.folders,
                          folderIDsContainingItem: itemModel.folderIDsContainingItem,
                          onWatchedToggle: { itemModel.toggleWatched() },
                          onFolderToggle: { itemModel.toggleFolder($0) })

        if let seasons = itemModel.mediaItem.seasons, !seasons.isEmpty {
          SeasonsRailView(seasons: seasons, linkProvider: itemModel.linkProvider)
        }

        if itemModel.itemLoaded {
          MediaItemRatingsSection(mediaItem: itemModel.mediaItem)
          MediaItemCastSection(mediaItem: itemModel.mediaItem)
          MediaItemInfoColumns(mediaItem: itemModel.mediaItem)
        }
      }
      .padding(.bottom, MediaItemLayout.sectionSpacing)
    }
    .background(ambientBackground)
    // Horizontal too, or the hero stops short of the screen edges on tvOS, where the
    // safe area is inset for overscan.
    .ignoresSafeArea(edges: [.top, .horizontal])
#if os(iOS)
    .toolbar(.hidden, for: .tabBar)
    .navigationBarTitleDisplayMode(.inline)
#endif
    .task {
      itemModel.fetchData()
    }
    .handleError(state: $errorHandler.state)
  }

  /// The artwork, blurred far past recognition, tinting the whole page — the colour
  /// wash microiptv puts behind its item pages. Blurring the small poster rather than
  /// the large one costs almost nothing and looks identical once this soft.
  private var ambientBackground: some View {
    ZStack {
      Color.KinoPub.background

      AsyncImage(url: URL(string: itemModel.mediaItem.posters.medium)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
          .blur(radius: 120, opaque: true)
          .saturation(1.6)
          .opacity(0.55)
      } placeholder: {
        Color.clear
      }

      Color.KinoPub.background.opacity(0.55)
    }
    .ignoresSafeArea()
  }
}

struct MediaItemView_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemView(model: MediaItemModel(mediaItemId: MediaItem.mock().id,
                                          itemsService: VideoContentServiceMock(),
                                          downloadManager: DownloadManager<DownloadMeta>(fileSaver: FileSaver(),
                                                                                      database: DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())),
                                          linkProvider: MainRoutesLinkProvider(),
                                          errorHandler: ErrorHandler()))
    }
  }
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
