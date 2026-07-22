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
          MediaItemCastSection(mediaItem: itemModel.mediaItem, linkProvider: itemModel.linkProvider)
          MediaItemInfoColumns(mediaItem: itemModel.mediaItem)
        }
      }
      .padding(.bottom, MediaItemLayout.sectionSpacing)
    }
    // Named so the hero can measure itself against the visible frame rather than
    // against the whole scrollable content.
    .coordinateSpace(name: MediaItemLayout.scrollSpace)
    .background(ambientBackground)
    // Horizontal too, or the hero stops short of the screen edges on tvOS, where the
    // safe area is inset for overscan.
    .ignoresSafeArea(edges: [.top, .horizontal])
    // The tab bar belongs to the browse surfaces, not to a pushed detail page.
    // Going back is the remote's Back button on tvOS and the navigation bar
    // elsewhere.
#if os(iOS) || os(tvOS)
    .toolbar(.hidden, for: .tabBar)
#endif
#if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
#endif
    .task {
      itemModel.fetchData()
    }
    .handleError(state: $errorHandler.state)
  }

  /// The artwork, blurred far past recognition, tinting the whole page — the colour
  /// wash microiptv puts behind its item pages.
  ///
  /// Blurred in a thumbnail-sized buffer and scaled up, not blurred at screen size:
  /// `.blur` becomes a Core Animation filter, and the render server re-applies it on
  /// every composited frame rather than caching the result, so a full-screen radius
  /// large enough to make a wash was a permanent per-frame cost. `drawingGroup()` pins
  /// the rasterisation to the small frame. Nothing is recognisable at this softness,
  /// so the upscale costs nothing visually.
  private var ambientBackground: some View {
    ZStack {
      Color.KinoPub.background

      AsyncImage(url: URL(string: itemModel.mediaItem.posters.medium)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: Self.ambientBuffer.width, height: Self.ambientBuffer.height)
          .clipped()
          .blur(radius: Self.ambientBlur, opaque: true)
          .saturation(1.6)
          .drawingGroup()
          .scaleEffect(Self.ambientScale)
          .opacity(0.55)
      } placeholder: {
        Color.clear
      }

      Color.KinoPub.background.opacity(0.55)
    }
    .clipped()
    .ignoresSafeArea()
  }

  /// 16:9, small enough that the blur is free and large enough that the upscale keeps
  /// its gradients smooth.
  private static let ambientBuffer = CGSize(width: 160, height: 90)
  /// Proportional to the buffer, so the wash reads the same as the full-size radius it
  /// replaces.
  private static let ambientBlur: CGFloat = 10
  /// Covers a 1080p screen with margin to spare; there is no detail here to misalign.
  private static let ambientScale: CGFloat = 14
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
