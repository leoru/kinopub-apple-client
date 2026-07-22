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

/// What the item page can put focus on by itself.
enum MediaItemFocusTarget: Hashable {
  case play
}

struct MediaItemView: View {

  @EnvironmentObject var errorHandler: ErrorHandler
  @StateObject private var itemModel: MediaItemModel

  /// The content arrives after the first render, so the focus engine has nothing to
  /// focus when the page appears — this names the Play button as where focus belongs
  /// once there is something to focus.
  ///
  /// The ScrollView has to stay the root for it to work: with the page wrapped in a
  /// `ZStack` instead, tvOS gave up on the late-arriving content entirely — the page
  /// opened scrolled past the hero with nothing focusable and the remote dead.
  @FocusState private var focus: MediaItemFocusTarget?

  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _itemModel = StateObject(wrappedValue: model())
  }

  var body: some View {
    details
      .background(ambientBackground)
      .overlay {
        // Nothing but the artwork wash while the details are in flight, and a spinner
        // only once the wait becomes noticeable — how the Apple TV app opens a page.
        if !itemModel.itemLoaded {
          LoadingIndicatorView(delay: .milliseconds(700))
        }
      }
      .animation(.easeInOut(duration: 0.3), value: itemModel.itemLoaded)
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

  private var details: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
        if itemModel.itemLoaded {
          MediaItemHeroView(mediaItem: itemModel.mediaItem,
                            focus: $focus,
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

          MediaItemRatingsSection(mediaItem: itemModel.mediaItem)
          MediaItemCastSection(mediaItem: itemModel.mediaItem)
          MediaItemInfoColumns(mediaItem: itemModel.mediaItem)
        }
      }
      .padding(.bottom, MediaItemLayout.sectionSpacing)
    }
#if os(tvOS)
    .defaultFocus($focus, .play)
#endif
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
