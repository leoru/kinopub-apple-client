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
import KinoPubMetadata

/// Focus targets owned by the hero. Play is separate so `defaultFocus` still lands
/// on it; everything else shares `heroOther`.
enum MediaItemFocusTarget: Hashable {
  case play
  case heroOther
  case plot
}

struct MediaItemView: View {

  @Environment(ErrorHandler.self) var errorHandler
  @EnvironmentObject var navigationState: NavigationState
  @StateObject private var itemModel: MediaItemModel
  /// Shared with the hero (Up → fullscreen) and, on tvOS, the pinned full-bleed
  /// backdrop behind the scroll view.
  @StateObject private var trailer: TrailerPreviewModel
  /// False once focus has left the hero — on tvOS fades the pinned wide still
  /// down to the blurred poster wash; on macOS also pauses the ambient trailer.
  @State private var isHeroOnScreen = true
  /// Scroll-driven wash scrub (0 at hero rest → 1 below fold). Focus still forces
  /// full wash via `isHeroOnScreen`; this intensifies the material as you scroll.
  @State private var washProgress: CGFloat = 0
  @FocusState private var focus: MediaItemFocusTarget?
#if os(macOS)
  /// The one-player rule (`PlaybackSession`) only covers the real film/trailer player.
  /// It says nothing about this page's own *ambient* hero preview, which is a second,
  /// independent `AVPlayer` (`TrailerPreviewModel`). Off macOS that preview stops for
  /// free: pushing the system player onto the stack fires `onDisappear` below. macOS
  /// opens a separate window instead — this page never disappears — so without this,
  /// the hero preview keeps animating behind the new window for as long as it's open.
  @ObservedObject private var playbackWindowState = PlaybackWindowState.shared
#endif

  init(model: @autoclosure @escaping () -> MediaItemModel) {
    _itemModel = StateObject(wrappedValue: model())
    _trailer = StateObject(wrappedValue: TrailerPreviewModel())
  }

  var body: some View {
    @Bindable var errorHandler = errorHandler
    details
      .background(pageBackground)
      .overlay {
        if itemModel.loadFailed {
          UnavailableView(
            title: "Couldn't Load",
            systemImage: "wifi.exclamationmark",
            message: itemModel.loadError?.userFacingMessage ?? "Check your connection and try again.".localized,
            retryTitle: "Try Again",
            onRetry: {
              itemModel.fetchData()
            }
          )
        } else if !itemModel.itemLoaded {
          LoadingIndicatorView(delay: .milliseconds(700))
        }
      }
      .animation(.easeInOut(duration: 0.3), value: itemModel.itemLoaded)
      .animation(.easeInOut(duration: 0.3), value: itemModel.loadFailed)
      // Top only: on macOS, ignoring horizontal safe area draws under the sidebar and
      // the first episode/poster gets clipped. tvOS/iOS still bleed the hero edge-to-edge.
#if os(macOS)
      .ignoresSafeArea(edges: .top)
#else
      .ignoresSafeArea(edges: [.top, .horizontal])
#endif
#if os(iOS) || os(tvOS)
      .toolbar(.hidden, for: .tabBar)
#endif
      // No navigation bar on this page, on either platform: the artwork runs to the
      // top edge and the title is already spelled out in 100pt over it. What stays is
      // the toolbar itself — Back and the overflow float over the picture.
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
#endif
#if os(macOS)
      .toolbarBackground(.hidden, for: .windowToolbar)
      .toolbarColorScheme(.dark, for: .windowToolbar)
#endif
      .platformNavigationTitle("")
#if os(iOS) || os(macOS)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          overflowMenu
        }
      }
#endif
      .task {
        itemModel.fetchData()
      }
      // Ambient muted trailer behind the hero:
      // - iPhone: off (short band, chrome on top — legibility / battery).
      // - tvOS: off for now (1C) — video without scrims looked broken; Trailer button
      //   still opens the real player. Revisit when the hero pass lands.
      // - macOS: on.
#if os(macOS)
      .task(id: itemModel.itemLoaded ? itemModel.mediaItem.trailerURL : nil) {
        guard itemModel.itemLoaded, let url = itemModel.mediaItem.trailerURL else { return }
        try? await Task.sleep(for: .seconds(MediaItemHeroView.trailerLeadIn))
        guard !Task.isCancelled else { return }
        trailer.start(url: url)
      }
#endif
      .onChange(of: isHeroOnScreen) { _, onScreen in
        trailer.setActive(onScreen)
      }
#if os(tvOS)
      .onChange(of: focus) { _, target in
        switch target {
        case .play, .heroOther, .plot:
          isHeroOnScreen = true
          washProgress = 0
        case .none:
          break
        }
      }
#endif
      .onDisappear {
        trailer.stop()
      }
#if os(macOS)
      .onChange(of: playbackWindowState.request?.id) { _, requestID in
        guard requestID != nil else { return }
        trailer.stop()
      }
#endif
      .handleError(state: $errorHandler.state)
      .hudToast($itemModel.hudToast)
  }

#if os(iOS) || os(macOS)
  /// The page's secondary actions, in the one place a platform with a toolbar puts
  /// them. Same list the tvOS hero shows in its overflow circle.
  private var overflowMenu: some View {
    Menu {
      MediaItemOverflowMenu(isSeries: itemModel.mediaItem.isSeries,
                            isWatched: itemModel.isWatched,
                            isBookmarked: itemModel.isBookmarked,
                            onWatchedToggle: { itemModel.toggleWatched() },
                            onClearFromContinueWatching: { itemModel.clearFromContinueWatching() },
                            onBrowseWatchlist: { Self.openWatchlist(navigationState) })
    } label: {
      Label("More", systemImage: "ellipsis")
    }
    .disabled(!itemModel.itemLoaded)
  }
#endif

  @ViewBuilder
  private var details: some View {
    if itemModel.itemLoaded {
      scrollDetails
        .defaultFocus($focus, .play)
    } else {
      Color.clear
    }
  }

  /// Single native vertical scroll: hero + content in one focus graph. Layout-driven
  /// scrolling replaces the old offset slideshow and invisible focus bridges.
  private var scrollDetails: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
        MediaItemHeroView(mediaItem: itemModel.mediaItem,
                          focus: $focus,
                          trailer: trailer,
                          isHeroOnScreen: $isHeroOnScreen,
                          washProgress: washProgress,
                          linkProvider: itemModel.linkProvider,
                          isWatched: itemModel.isWatched,
                          isBookmarked: itemModel.isBookmarked,
                          folders: itemModel.folders,
                          folderIDsContainingItem: itemModel.folderIDsContainingItem,
                          onWatchedToggle: { itemModel.toggleWatched() },
                          onSeasonWatchedToggle: { itemModel.toggleWatched(season: $0) },
                          onFolderToggle: { itemModel.toggleFolder($0) },
                          onCreateFolder: { itemModel.createFolderAndAdd(named: $0) },
                          onClearFromContinueWatching: { itemModel.clearFromContinueWatching() },
                          onBrowseWatchlist: { Self.openWatchlist(navigationState) },
                          isInWatchlist: itemModel.isInWatchlist,
                          onToggleWatchlist: { itemModel.toggleWatchlist() },
                          titleLogoURL: itemModel.externalMetadata.titleLogoURL,
                          ageRating: itemModel.externalMetadata.ageRating,
                          externalMetadataLoaded: itemModel.externalMetadataLoaded)
#if os(tvOS)
          .containerRelativeFrame(.vertical) { length, _ in length }
          .focusSection()
#endif

        contentSections
      }
      .padding(.bottom, MediaItemLayout.bottomPadding)
    }
    .coordinateSpace(name: MediaItemLayout.scrollSpace)
#if os(tvOS)
    // No `.viewAligned` on the vertical detail scroll — it fought section focus
    // and pinned a full-viewport hero so the info panel never settled on screen.
    // Home banners keep viewAligned on their own horizontal rails.
    .onScrollGeometryChange(for: CGFloat.self) { geo in
      geo.contentOffset.y + geo.contentInsets.top
    } action: { _, offset in
      // Rivulet uses ~600pt reserve; map into 0…1 for material scrub.
      let progress = min(max(offset / Self.washScrollDistance, 0), 1)
      if abs(progress - washProgress) > 0.01 {
        washProgress = progress
      }
    }
#endif
  }

  /// Fired when any below-hero section takes focus — flips the backdrop wash.
  private var leaveHero: () -> Void {
    { isHeroOnScreen = false }
  }

  @ViewBuilder
  private var contentSections: some View {
    VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
      if let seasons = itemModel.mediaItem.seasons, !seasons.isEmpty {
        SeasonsRailView(seasons: seasons,
                        linkProvider: itemModel.linkProvider,
                        seriesTitle: itemModel.mediaItem.localizedTitle,
                        showsChrome: true,
                        onSectionFocused: leaveHero,
                        onHide: { episode, season in
                          itemModel.hide(episode: episode, season: season)
                        },
                        onToggleWatched: { episode, season in
                          itemModel.toggleWatched(episode: episode, season: season)
                        },
                        seasonSchedules: itemModel.seasonSchedules,
                        externalMetadata: itemModel.externalMetadata,
                        onSeasonVisible: { seasonNumber in
                          Task { await itemModel.ensureSeasonSchedule(seasonNumber) }
                        })
      }

      MediaItemRatingsSection(mediaItem: itemModel.mediaItem,
                              showsHeader: true,
                              onSectionFocused: leaveHero)
      MediaItemCommunityVoteSection(likeCount: itemModel.likeCount,
                                    dislikeCount: itemModel.dislikeCount,
                                    myVote: itemModel.myVote,
                                    onVote: { itemModel.vote(up: $0) },
                                    onSectionFocused: leaveHero)
      MediaItemCastSection(mediaItem: itemModel.mediaItem,
                           linkProvider: itemModel.linkProvider,
                           externalMetadata: itemModel.externalMetadata,
                           externalMetadataLoaded: itemModel.externalMetadataLoaded,
                           onSectionFocused: leaveHero)
      MediaItemAwardsSection(awards: itemModel.externalMetadata.awards,
                             onSectionFocused: leaveHero)
      MediaItemPhotosSection(stills: itemModel.externalMetadata.stills,
                             onSectionFocused: leaveHero)
#if !os(tvOS)
      MediaItemFactsSection(facts: itemModel.externalMetadata.facts,
                            onSectionFocused: leaveHero)
      MediaItemReviewsSection(reviews: itemModel.externalMetadata.reviews,
                              onSectionFocused: leaveHero)
#endif
      MediaItemSimilarSection(items: itemModel.similarItems,
                              linkProvider: itemModel.linkProvider,
                              onSectionFocused: leaveHero)
      MediaItemPersonShelfSection(titleFormat: "More from %@",
                                  person: itemModel.primaryDirector,
                                  items: itemModel.moreFromDirector,
                                  isLoaded: itemModel.moreFromDirectorLoaded,
                                  linkProvider: itemModel.linkProvider,
                                  onSectionFocused: leaveHero)
      MediaItemPersonShelfSection(titleFormat: "More with %@",
                                  person: itemModel.primaryActor,
                                  items: itemModel.moreWithActor,
                                  isLoaded: itemModel.moreWithActorLoaded,
                                  linkProvider: itemModel.linkProvider,
                                  onSectionFocused: leaveHero)
      MediaItemInfoColumns(mediaItem: itemModel.mediaItem,
                           externalMetadata: itemModel.externalMetadata,
                           onSectionFocused: leaveHero)
    }
  }

  @ViewBuilder
  private var pageBackground: some View {
#if os(tvOS)
    if itemModel.itemLoaded {
      MediaItemHeroBackdrop(mediaItem: itemModel.mediaItem,
                            trailer: trailer,
                            isHeroOnScreen: isHeroOnScreen,
                            washProgress: washProgress)
    } else {
      ambientBackground
    }
#else
    ambientBackground
#endif
  }

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
#if os(macOS)
    // Horizontal ignore paints the wash under the sidebar and makes every rail
    // look clipped; keep the bleed on tvOS/iOS only.
    .ignoresSafeArea(edges: .top)
#else
    .ignoresSafeArea()
#endif
  }

  private static let ambientBuffer = CGSize(width: 160, height: 90)
  private static let ambientBlur: CGFloat = 10
  private static let ambientScale: CGFloat = 14
  /// Rivulet-style reserve distance for wash scrub (~600pt).
  private static let washScrollDistance: CGFloat = 600

  private static func openWatchlist(_ navigationState: NavigationState) {
#if os(macOS)
    navigationState.selectedTab = .watchlist
#else
    navigationState.selectedTab = .library
#endif
  }
}

#if os(tvOS)
/// Reports when a control inside a detail section takes focus.
struct MediaItemSectionFocusReporter: ViewModifier {
  let onSectionFocused: () -> Void
  @Environment(\.isFocused) private var isFocused

  func body(content: Content) -> some View {
    content.onChange(of: isFocused) { _, focused in
      if focused { onSectionFocused() }
    }
  }
}

extension View {
  @ViewBuilder
  func reportMediaItemSectionFocus(_ handler: (() -> Void)?) -> some View {
    if let handler {
      modifier(MediaItemSectionFocusReporter(onSectionFocused: handler))
    } else {
      self
    }
  }
}
#endif

struct MediaItemView_Previews: PreviewProvider {
  struct Preview: View {
    var body: some View {
      MediaItemView(model: MediaItemModel(mediaItemId: MediaItem.mock().id,
                                          itemsService: VideoContentServiceMock(),
                                          downloadManager: DownloadManager<DownloadMeta>(fileSaver: FileSaver(),
                                                                                      database: DownloadedFilesDatabase<DownloadMeta>(fileSaver: FileSaver())),
                                          linkProvider: AppRoutesLinkProvider(),
                                          errorHandler: ErrorHandler()))
    }
  }
  static var previews: some View {
    NavigationStack {
      Preview()
    }
  }
}
