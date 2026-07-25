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

/// Focus targets owned by the hero. Play is separate so `defaultFocus` still lands
/// on it; everything else shares `heroOther`. Anything below the hero is untagged —
/// Down onto seasons/ratings/cast clears this and fades the trailer.
enum MediaItemFocusTarget: Hashable {
  case play
  case heroOther
}

#if os(tvOS)
/// Outer vertical slideshow: exactly two full-screen slides. The focus engine never
/// owns this axis — we offset between them — so walking Play ↔ plot ↔ buttons cannot
/// nudge the page by a few pixels.
private enum MediaItemSlide {
  case hero
  case content
}

/// Anchors inside the content slide's own `ScrollView`. `.top` is the first band
/// (seasons, or ratings on a movie) and stays pinned while focus walks inside it.
enum MediaItemContentAnchor: String, Hashable {
  case top
  case ratings
  case cast
  case similar
  case info
}
#endif

struct MediaItemView: View {

  @EnvironmentObject var errorHandler: ErrorHandler
  @EnvironmentObject var navigationState: NavigationState
  @StateObject private var itemModel: MediaItemModel
  /// Shared with the hero (Up → fullscreen) and, on tvOS, the pinned full-bleed
  /// backdrop behind the scroll view.
  @StateObject private var trailer = TrailerPreviewModel()
  /// False once focus has left the hero — pauses the trailer and, on tvOS, fades
  /// the pinned wide/trailer layer down to the blurred poster wash.
  @State private var isHeroOnScreen = true
#if os(tvOS)
  @State private var slide: MediaItemSlide = .hero
  @State private var contentAnchor: MediaItemContentAnchor = .top
  @State private var contentSnapToken: Int = 0
#endif

  /// The content arrives after the first render, so the focus engine has nothing to
  /// focus when the page appears — this names a hero control as where focus belongs
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
      .background(pageBackground)
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
    // Keyed on load + URL: the listing's `knownItem` can already carry a trailer
    // link, but the hero only appears once details land — without `itemLoaded` in
    // the id the first run would no-op and never retry for the same URL.
    .task(id: itemModel.itemLoaded ? itemModel.mediaItem.trailerURL : nil) {
      guard itemModel.itemLoaded, let url = itemModel.mediaItem.trailerURL else { return }
      // The artwork holds the frame for a beat before the trailer takes over, the way
      // the Apple TV app does it — and a quick scroll past doesn't spin up a video.
      try? await Task.sleep(for: .seconds(MediaItemHeroView.trailerLeadIn))
      guard !Task.isCancelled else { return }
      trailer.start(url: url)
    }
#if os(tvOS)
    .onChange(of: focus) { newFocus in
      if newFocus != nil {
        showHeroSlide()
      }
    }
#endif
    .onChange(of: isHeroOnScreen) { onScreen in
      trailer.setActive(onScreen)
    }
    .onDisappear {
      trailer.stop()
    }
    .handleError(state: $errorHandler.state)
  }

  @ViewBuilder
  private var details: some View {
#if os(tvOS)
    if itemModel.itemLoaded {
      slideshow
    } else {
      Color.clear
    }
#else
    legacyScrollDetails
#endif
  }

#if os(tvOS)
  /// Two full-viewport slides stacked vertically; we offset between them. The content
  /// slide owns a nested `ScrollView` that always opens at its top — seasons/episodes
  /// never fight the hero for a few pixels of focus scrolling.
  private var slideshow: some View {
    GeometryReader { geo in
      let size = geo.size

      VStack(spacing: 0) {
        heroSlide
          .frame(width: size.width, height: size.height)
          .focusSection()

        contentSlide
          .frame(width: size.width, height: size.height)
          .focusSection()
      }
      .offset(y: slide == .hero ? 0 : -size.height)
      .frame(width: size.width, height: size.height, alignment: .top)
      .clipped()
      .animation(.easeOut(duration: 0.3), value: slide)
    }
    .defaultFocus($focus, .play)
  }

  private var heroSlide: some View {
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
                      onFolderToggle: { itemModel.toggleFolder($0) })
  }

  private var contentSlide: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
          // Zero-height pin so the first band (seasons *or* ratings) shares one
          // stable top anchor — focusing tabs vs episodes can't pick different pads.
          Color.clear
            .frame(height: 0)
            .id(MediaItemContentAnchor.top)

          if let seasons = itemModel.mediaItem.seasons, !seasons.isEmpty {
            SeasonsRailView(seasons: seasons,
                            linkProvider: itemModel.linkProvider,
                            seriesTitle: itemModel.mediaItem.localizedTitle,
                            showsChrome: true,
                            onSectionFocused: { activateContent(.top) },
                            onHide: { episode, season in
                              itemModel.hide(episode: episode, season: season)
                            },
                            onToggleWatched: { episode, season in
                              itemModel.toggleWatched(episode: episode, season: season)
                            })
          }

          MediaItemRatingsSection(mediaItem: itemModel.mediaItem,
                                  showsHeader: true,
                                  onSectionFocused: {
                                    activateContent(hasSeasons ? .ratings : .top)
                                  })
            .id(MediaItemContentAnchor.ratings)

          MediaItemCastSection(mediaItem: itemModel.mediaItem,
                               linkProvider: itemModel.linkProvider,
                               onSectionFocused: { activateContent(.cast) })
            .id(MediaItemContentAnchor.cast)

          MediaItemSimilarSection(items: itemModel.similarItems,
                                  linkProvider: itemModel.linkProvider,
                                  onSectionFocused: { activateContent(.similar) })
            .id(MediaItemContentAnchor.similar)

          MediaItemInfoColumns(mediaItem: itemModel.mediaItem,
                               onSectionFocused: { activateContent(.info) })
            .id(MediaItemContentAnchor.info)
        }
        .padding(.top, MediaItemLayout.sectionSpacing)
        .padding(.bottom, MediaItemLayout.sectionSpacing)
      }
      .onChange(of: contentSnapToken) { _ in
        snapContent(proxy: proxy)
      }
    }
  }

  private var hasSeasons: Bool {
    !(itemModel.mediaItem.seasons?.isEmpty ?? true)
  }

  private func showHeroSlide() {
    slide = .hero
    isHeroOnScreen = true
  }

  /// Flip to the content slide (if needed) and pin its inner scroll to `anchor`.
  private func activateContent(_ anchor: MediaItemContentAnchor) {
    let slideChanged = slide != .content
    let anchorChanged = contentAnchor != anchor
    slide = .content
    isHeroOnScreen = false
    contentAnchor = anchor
    // Re-snap while parked on `.top` so episode/tab focus can't drift; later
    // sections only snap when entered.
    if slideChanged || anchorChanged || anchor == .top {
      contentSnapToken &+= 1
    }
  }

  private func snapContent(proxy: ScrollViewProxy) {
    let anchor: UnitPoint = contentAnchor == .info ? .bottom : .top
    let target: MediaItemContentAnchor = contentAnchor
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(16))
      withAnimation(.easeOut(duration: 0.25)) {
        proxy.scrollTo(target, anchor: anchor)
      }
    }
  }
#endif

#if !os(tvOS)
  private var legacyScrollDetails: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: MediaItemLayout.sectionSpacing) {
        if itemModel.itemLoaded {
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
                            onFolderToggle: { itemModel.toggleFolder($0) },
                            onClearFromContinueWatching: { itemModel.clearFromContinueWatching() },
                            onBrowseWatchlist: { navigationState.selectedTab = .saved })

          if let seasons = itemModel.mediaItem.seasons, !seasons.isEmpty {
            SeasonsRailView(seasons: seasons,
                            linkProvider: itemModel.linkProvider,
                            seriesTitle: itemModel.mediaItem.localizedTitle,
                            showsChrome: true,
                            onHide: { episode, season in
                              itemModel.hide(episode: episode, season: season)
                            },
                            onToggleWatched: { episode, season in
                              itemModel.toggleWatched(episode: episode, season: season)
                            })
          }

          MediaItemRatingsSection(mediaItem: itemModel.mediaItem, showsHeader: true)
          MediaItemCastSection(mediaItem: itemModel.mediaItem, linkProvider: itemModel.linkProvider)
          MediaItemSimilarSection(items: itemModel.similarItems, linkProvider: itemModel.linkProvider)
          MediaItemInfoColumns(mediaItem: itemModel.mediaItem)
        }
      }
      .padding(.bottom, MediaItemLayout.sectionSpacing)
    }
    .coordinateSpace(name: MediaItemLayout.scrollSpace)
  }
#endif

  /// On tvOS the loaded page pins a small-poster wash plus the wide/trailer hero
  /// layer behind the scroll view; elsewhere — and while details are still in
  /// flight — the soft ambient wash stays.
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

#if os(tvOS)
/// Reports when a control inside a detail section takes focus, so the page can snap
/// to that section without each call site wiring `@Environment(\.isFocused)`.
struct MediaItemSectionFocusReporter: ViewModifier {
  let onSectionFocused: () -> Void
  @Environment(\.isFocused) private var isFocused

  func body(content: Content) -> some View {
    content.onChange(of: isFocused) { focused in
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
