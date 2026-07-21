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
      VStack(alignment: .leading, spacing: Self.sectionSpacing) {
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

        detailsSection
      }
      .padding(.bottom, Self.sectionSpacing)
    }
    .background(Color.KinoPub.background)
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

  private var detailsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("MediaItem_Details")

      MediaItemFieldsCard(mediaItem: itemModel.mediaItem,
                          isSkeleton: !itemModel.itemLoaded)
      .frame(maxWidth: Self.textMaxWidth, alignment: .leading)
      .padding(.horizontal, Self.horizontalInset)
    }
  }

  private func sectionHeader(_ key: LocalizedStringKey) -> some View {
    Text(key)
      .font(Self.headerFont)
      .foregroundStyle(Color.KinoPub.text)
      .padding(.horizontal, Self.horizontalInset)
  }

#if os(tvOS)
  static let sectionSpacing: CGFloat = 40
  static let horizontalInset: CGFloat = 80
  static let textMaxWidth: CGFloat = 1400
  static let headerFont: Font = .system(size: 32, weight: .semibold)
  static let bodyFont: Font = .system(size: 26, weight: .regular)
#elseif os(macOS)
  static let sectionSpacing: CGFloat = 28
  static let horizontalInset: CGFloat = 32
  static let textMaxWidth: CGFloat = 900
  static let headerFont: Font = .system(size: 22, weight: .semibold)
  static let bodyFont: Font = .system(size: 15, weight: .regular)
#else
  static let sectionSpacing: CGFloat = 24
  static let horizontalInset: CGFloat = 20
  static let textMaxWidth: CGFloat = 700
  static let headerFont: Font = .system(size: 20, weight: .semibold)
  static let bodyFont: Font = .system(size: 15, weight: .regular)
#endif
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
