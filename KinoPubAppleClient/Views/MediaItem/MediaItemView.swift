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

/// Focus targets owned by the hero. One case per button — SIX of them used to share
/// `heroOther`, which is why tvOS focus froze dead on Play: with multiple sibling
/// views bound to the same `@FocusState` equals-value, the engine has no way to
/// resolve which one is actually focused, and directional moves in and out of the
/// group (including Right into the row, and Down past it) simply stop resolving.
enum MediaItemFocusTarget: Hashable {
  case play
  case watchlist
  case bookmark
  case watched
  case trailer
  case more
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
      // Tabs stay visible over the detail page for now (2026-08-09): the hide-on-enter
      // here plus the system's own tab-bar minimize timing was reading as "tabs fade in
      // and out in random places." Revisit properly later; until then, always-on beats
      // unpredictable. See `docs/en/plans/detail-page-choreography.md`.
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
      // Focus landing on ANY hero control means "the hero section is current" — the
      // section is the unit, not the individual button. Sections below report the
      // opposite through `leaveHero`. Those two writers are the whole wash state.
      .onChange(of: focus) { _, target in
        switch target {
        case .play, .watchlist, .bookmark, .watched, .trailer, .more, .plot:
          isHeroOnScreen = true
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
  ///
  /// Phase 1 of `docs/en/plans/detail-page-choreography.md` tried pulling the hero
  /// out of this `ScrollView` into a fixed `ZStack` layer, to stop focus moves among
  /// Play / Watched / Watchlist from nudging the scroll offset. **Reverted** —
  /// on-device it broke tvOS spatial focus across the ZStack/ScrollView sibling
  /// boundary outright: focus could not leave Play at all, Down only worked when a
  /// season rail happened to be the first section, Up never worked, Menu closed the
  /// app instead of popping, and the permanently-present hero visually collided with
  /// section content that was never tall enough to fully cover it. See the plan for
  /// the full account before attempting this again — it needs a design that doesn't
  /// split hero and scroll into ZStack siblings.
  private var scrollDetails: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
        MediaItemHeroView(mediaItem: itemModel.mediaItem,
                          focus: $focus,
                          trailer: trailer,
                          isHeroOnScreen: $isHeroOnScreen,
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
    // No `.viewAligned` on the vertical detail scroll — it fought section focus and
    // pinned a full-viewport hero so the info panel never settled on screen. Home
    // banners keep viewAligned on their own horizontal rails.
    //
    // No `onScrollGeometryChange` either, deliberately: driving the wash from scroll
    // offset re-ran this body on every scroll frame, which re-rendered every shelf
    // below — including each `TVUIKitMediaCollection`'s `updateUIViewController`. The
    // wash is section state now (`isHeroOnScreen`), so nothing here needs per-frame
    // work. See `docs/en/plans/detail-page-choreography.md`.
  }

  /// Fired when any below-hero section takes focus — flips the backdrop wash.
  private var leaveHero: () -> Void {
    { isHeroOnScreen = false }
  }

  /// Real seasons, or — under `FeatureFlags.fakeSeasonsOnMovies` — a fabricated one for
  /// titles that have none. **Temporary diagnostic, delete with the flag.**
  private var seasonsForDisplay: [Season]? {
    if let real = itemModel.mediaItem.seasons, !real.isEmpty { return real }
    guard FeatureFlags.fakeSeasonsOnMovies, itemModel.itemLoaded else { return nil }
    return Self.probeSeason(for: itemModel.mediaItem).map { [$0] }
  }

  /// One season of six unplayable episodes reusing the title's own artwork, so the rail
  /// renders at realistic size. **Temporary diagnostic, delete with the flag.**
  ///
  /// `EpisodeWatching` / `SeasonWatching` are `Codable` structs whose memberwise init is
  /// internal to `KinoPubBackend`, so they are decoded from literals here rather than
  /// widening those models' API for a throwaway probe.
  private static func probeSeason(for item: MediaItem) -> Season? {
    func decoded<T: Decodable>(_ json: String) -> T? {
      try? JSONDecoder().decode(T.self, from: Data(json.utf8))
    }
    guard let seasonWatching: SeasonWatching = decoded(#"{"status":-1}"#) else { return nil }

    let still = item.posters.wideURL ?? item.posters.medium
    let episodes: [Episode] = (1...6).compactMap { number in
      // Two watched, one mid-progress, rest fresh — enough states to see the rail's chrome.
      let status = number <= 2 ? 1 : -1
      let time = number == 3 ? 600 : 0
      guard let watching: EpisodeWatching = decoded(#"{"status":\#(status),"time":\#(time)}"#)
      else { return nil }
      return Episode(id: item.id * 1000 + number,
                     title: "Probe episode \(number)",
                     thumbnail: still,
                     duration: 60 * 42,
                     tracks: 1,
                     number: number,
                     ac3: 0,
                     audios: [],
                     watched: number <= 2 ? 1 : 0,
                     watching: watching,
                     subtitles: [],
                     files: [])
    }
    guard !episodes.isEmpty else { return nil }
    return Season(id: item.id * 1000,
                  title: "Probe season",
                  number: 1,
                  watching: seasonWatching,
                  episodes: episodes)
  }

  @ViewBuilder
  private var contentSections: some View {
    VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
      if let seasons = seasonsForDisplay, !seasons.isEmpty {
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
        .detailFocusSection()
      MediaItemCastSection(mediaItem: itemModel.mediaItem,
                           linkProvider: itemModel.linkProvider,
                           externalMetadata: itemModel.externalMetadata,
                           externalMetadataLoaded: itemModel.externalMetadataLoaded,
                           onSectionFocused: leaveHero)
        .detailFocusSection()
      MediaItemAwardsSection(awards: itemModel.externalMetadata.awards,
                             onSectionFocused: leaveHero)
        .detailFocusSection()
      MediaItemPhotosSection(stills: itemModel.externalMetadata.stills,
                             onSectionFocused: leaveHero)
        .detailFocusSection()
#if !os(tvOS)
      MediaItemFactsSection(facts: itemModel.externalMetadata.facts,
                            onSectionFocused: leaveHero)
      MediaItemReviewsSection(reviews: itemModel.externalMetadata.reviews,
                              onSectionFocused: leaveHero)
#endif
      MediaItemSimilarSection(items: itemModel.similarItems,
                              linkProvider: itemModel.linkProvider,
                              onSectionFocused: leaveHero)
        .detailFocusSection()
      MediaItemPersonShelfSection(titleFormat: "More from %@",
                                  person: itemModel.primaryDirector,
                                  items: itemModel.moreFromDirector,
                                  isLoaded: itemModel.moreFromDirectorLoaded,
                                  linkProvider: itemModel.linkProvider,
                                  onSectionFocused: leaveHero)
        .detailFocusSection()
      MediaItemPersonShelfSection(titleFormat: "More with %@",
                                  person: itemModel.primaryActor,
                                  items: itemModel.moreWithActor,
                                  isLoaded: itemModel.moreWithActorLoaded,
                                  linkProvider: itemModel.linkProvider,
                                  onSectionFocused: leaveHero)
        .detailFocusSection()
      MediaItemInfoColumns(mediaItem: itemModel.mediaItem,
                           externalMetadata: itemModel.externalMetadata,
                           onSectionFocused: leaveHero)
        .detailFocusSection()
    }
  }

  @ViewBuilder
  private var pageBackground: some View {
#if os(tvOS)
    if itemModel.itemLoaded {
      MediaItemHeroBackdrop(mediaItem: itemModel.mediaItem,
                            trailer: trailer,
                            isHeroOnScreen: isHeroOnScreen)
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

extension View {
  /// One focus section per detail-page content section, so Up/Down travels
  /// section-to-section instead of creeping element-by-element, and a section holds
  /// focus internally while you move across it. The hero is the same shape one level
  /// up — a full-viewport `focusSection` — which is what lets "the hero is current" be
  /// a single state rather than something inferred per button.
  ///
  /// Only applied to sections that do not already declare their own: the ratings row
  /// and `SeasonsRailView` build theirs internally, and nesting would fight them.
  @ViewBuilder
  func detailFocusSection() -> some View {
#if os(tvOS)
    focusSection()
#else
    self
#endif
  }
}

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
