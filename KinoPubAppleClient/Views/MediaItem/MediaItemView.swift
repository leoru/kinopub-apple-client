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
                          onWatchedToggle: {},
                          onBookmarkHandle: {})

        if let seasons = itemModel.mediaItem.seasons, !seasons.isEmpty {
          seasonsSection(seasons)
        }

        detailsSection
      }
      .padding(.bottom, Self.sectionSpacing)
    }
    .background(Color.KinoPub.background)
    .ignoresSafeArea(edges: .top)
#if os(iOS)
    .toolbar(.hidden, for: .tabBar)
    .navigationBarTitleDisplayMode(.inline)
#endif
    .task {
      itemModel.fetchData()
    }
    .handleError(state: $errorHandler.state)
  }

  private func seasonsSection(_ seasons: [Season]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Seasons")

      ScrollView(.horizontal, showsIndicators: false) {
        LazyHStack(spacing: 16) {
          ForEach(seasons) { season in
            NavigationLink(value: itemModel.linkProvider.season(for: season)) {
              SeasonChip(season: season)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
          }
        }
        .padding(.horizontal, Self.horizontalInset)
        .padding(.vertical, 8)
      }
    }
  }

  private var detailsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("MediaItem_Description")

      VStack(alignment: .leading, spacing: 10) {
        Text(itemModel.mediaItem.plot)
          .font(Self.bodyFont)
          .foregroundStyle(Color.KinoPub.text)
          .multilineSkeleton(enabled: !itemModel.itemLoaded)

        MediaItemFieldsCard(mediaItem: itemModel.mediaItem,
                            isSkeleton: !itemModel.itemLoaded)
      }
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

/// A season tile: number, episode count and how far through it the user is.
private struct SeasonChip: View {
  let season: Season

  private var watchedCount: Int {
    season.episodes.filter { $0.watched > 0 }.count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(season.fixedTitle)
        .font(Self.titleFont)
        .lineLimit(1)
      Text("\(watchedCount)/\(season.episodes.count)")
        .font(Self.captionFont)
        .foregroundStyle(Color.KinoPub.subtitle)
    }
    .frame(width: Self.width, alignment: .leading)
  }

#if os(tvOS)
  static let width: CGFloat = 240
  static let titleFont: Font = .system(size: 28, weight: .medium)
  static let captionFont: Font = .system(size: 22, weight: .regular)
#else
  static let width: CGFloat = 120
  static let titleFont: Font = .system(size: 15, weight: .medium)
  static let captionFont: Font = .system(size: 13, weight: .regular)
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
