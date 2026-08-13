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

/// Whether the hero is the current section, as its own `@Observable` rather than a
/// `@State` on `MediaItemView` itself. The distinction matters: `@State` invalidates
/// the *owning* view's `body` on every write, whether or not that body actually reads
/// the value — so as long as this lived on `MediaItemView`, every hero↔section
/// transition forced the whole page (all of `contentSections`, every
/// `TVUIKitMediaCollection` in it) to re-render, on top of the `@FocusState`-driven
/// rerun the same transition already causes. `@Observable` tracks reads per view: only
/// `MediaItemHeroBackdrop` and `MediaItemHeroView` — the two views that actually read
/// `isHeroOnScreen` inside their own `body` — re-render when it changes.
///
/// `MediaItemView.body` must never read `.isHeroOnScreen` directly (only construct
/// child views with a reference to the object, or write through it in a closure); doing
/// so would reintroduce the same dependency this exists to avoid.
@Observable
final class MediaItemHeroPhase {
  var isHeroOnScreen = true
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
  /// See `MediaItemHeroPhase` for why this is a `@State`-held reference type and
  /// not a plain `@State private var isHeroOnScreen: Bool`.
  @State private var heroPhase = MediaItemHeroPhase()
  /// Measured hero height — the one number the fold snap needs.
  @State private var showcaseHeight: CGFloat = 0
  @FocusState private var focus: MediaItemFocusTarget?
  /// Owns folder state + context-menu wiring for the related-item rows (Similar /
  /// More from Director / More with Actor) as ONE coordinator shared across all of
  /// them — see `MediaItemRelatedRowsSection`. Previously each of those three
  /// shelves created and bound its own `MediaCardMenuCoordinator` independently.
  @StateObject private var relatedRowsMenu = MediaCardMenuCoordinator()
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
      // unpredictable. See `docs/archive/plans/detail-page-choreography.md`.
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
      .task {
        relatedRowsMenu.bind(errorHandler: errorHandler)
        await relatedRowsMenu.refreshFolders()
      }
      .mediaCardNewFolderAlert(relatedRowsMenu)
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
      // `trailer.setActive` lives on `MediaItemHeroView`'s own `onChange` now — see
      // `MediaItemHeroPhase` — so this page never reads `heroPhase.isHeroOnScreen`.
#if os(tvOS)
      // Focus landing on ANY hero control means "the hero section is current" — the
      // section is the unit, not the individual button. Sections below report the
      // opposite through `leaveHero`. Those two writers are the whole wash state.
      // A write through `heroPhase`, not a read — does not couple this page's body
      // to the value (see `MediaItemHeroPhase`).
      .onChange(of: focus) { _, target in
        FocusLog.moved(section: "hero",
                       element: target.map { "\($0)" } ?? "none",
                       focused: target != nil)
        // The fold, and its only writer. `focus` is non-nil exactly while one of the
        // hero's own controls holds focus; the moment focus moves to anything below
        // it goes nil. That is the whole state: focus in the hero → the page belongs
        // to the hero; focus anywhere else → it belongs to the sections.
        heroPhase.isHeroOnScreen = target != nil
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
  /// Phase 1 of `docs/archive/plans/detail-page-choreography.md` tried pulling the hero
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
                          phase: heroPhase,
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
          // Screen height MINUS a peek strip, not the whole viewport. That subtraction
          // is what makes the resting hero state show a slice of the first section at
          // the bottom — the affordance that says "there is more below" — and it is
          // also what gives the snap behaviour below a height to snap to.
          .containerRelativeFrame(.vertical, alignment: .topLeading) { length, _ in
            length * MediaItemLayout.heroFraction
          }
          // Restored (it was commented out): Apple's tvOS layout guidance calls this
          // out by name — without a full-width focus section on the header, "moving
          // focus up from the right side of the shelves below might fail, or might
          // jump all the way to the tab bar", because the engine searches straight up
          // from the focused item. That is verbatim the Up-from-sections bug this page
          // has been carrying.
          .frame(maxWidth: .infinity, alignment: .leading)
          .focusSection()
          .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
          } action: { height in
            showcaseHeight = height
          }
          // NOT `onScrollVisibilityChange`. Deriving the fold from how much of the
          // hero is on screen is circular on a page that moves by focus: the scroll
          // decides the fold, and the fold decides where to scroll. The fold is a
          // property of *where focus is*, and focus is the thing the user moves —
          // see the `focus` observer on `body`.
#endif

        contentSections
      }
      .padding(.bottom, MediaItemLayout.bottomPadding)
    }
    .coordinateSpace(name: MediaItemLayout.scrollSpace)
#if os(tvOS)
    // The snap. A *custom* `ScrollTargetBehavior` — not `.viewAligned`, which this
    // page tried before and which fought section focus; that experiment was recorded
    // as "no scroll target behaviour here", which was the wrong conclusion drawn from
    // the right result. This rewrites the scroll target from inside the native scroll
    // instead of chasing it from outside with `scrollTo`, so there is nothing for the
    // focus engine's own scroll animator to fight.
    .scrollTargetBehavior(
      MediaItemFoldSnappingBehavior(aboveFold: heroPhase.isHeroOnScreen,
                                    showcaseHeight: showcaseHeight)
    )
#endif
    // No `.viewAligned` on the vertical detail scroll — it fought section focus and
    // pinned a full-viewport hero so the info panel never settled on screen. Home
    // banners keep viewAligned on their own horizontal rails.
    //
    // No `onScrollGeometryChange` either, deliberately: driving the wash from scroll
    // offset re-ran this body on every scroll frame, which re-rendered every shelf
    // below — including each `TVUIKitMediaCollection`'s `updateUIViewController`. The
    // wash is section state now (`isHeroOnScreen`), so nothing here needs per-frame
    // work. See `docs/archive/plans/detail-page-choreography.md`.
#if os(tvOS)
    // Phase 2 of the same plan: small title logo pinned at the top once focus has
    // left the hero. `.overlay` on the `ScrollView` draws fixed relative to its own
    // frame — content scrolls under it, it does not scroll with content — and is
    // purely visual (non-focusable), so it carries none of the risk phase 1's
    // ZStack-sibling *focusable* hero content did (see the plan's account of that
    // revert). Passing `heroPhase` itself, not `heroPhase.isHeroOnScreen`, keeps this
    // page's own body from depending on the value — see `MediaItemHeroPhase`.
    .overlay(alignment: .top) {
      MediaItemTitleLogoHeader(phase: heroPhase,
                               titleLogoURL: itemModel.externalMetadata.titleLogoURL,
                               title: itemModel.mediaItem.localizedTitle)
    }
#endif
  }

  /// Fired when any below-hero section takes focus — flips the backdrop wash.
  /// A write through `heroPhase`, not a read — this closure capturing `heroPhase`
  /// (the object) rather than its current value is what keeps this page's own body
  /// from depending on `isHeroOnScreen` (see `MediaItemHeroPhase`).
  private var leaveHero: () -> Void {
    { heroPhase.isHeroOnScreen = false }
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
                        onUnavailableSelected: { message in
                          itemModel.hudToast = HudToast(systemImage: "clock", title: message)
                        },
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
        .detailFocusSection("vote")
      MediaItemCastSection(mediaItem: itemModel.mediaItem,
                           linkProvider: itemModel.linkProvider,
                           externalMetadata: itemModel.externalMetadata,
                           onSectionFocused: leaveHero)
        .detailFocusSection("cast")
      MediaItemAwardsSection(awards: itemModel.externalMetadata.awards,
                             onSectionFocused: leaveHero)
        .detailFocusSection("awards")
      MediaItemPhotosSection(stills: itemModel.externalMetadata.stills,
                             onSectionFocused: leaveHero)
        .detailFocusSection("photos")
#if !os(tvOS)
      MediaItemFactsSection(facts: itemModel.externalMetadata.facts,
                            onSectionFocused: leaveHero)
      MediaItemReviewsSection(reviews: itemModel.externalMetadata.reviews,
                              onSectionFocused: leaveHero)
#endif
      MediaItemRelatedRowsSection(rows: itemModel.relatedRows,
                                  relatedItem: { itemModel.relatedItem(forCardID: $0) },
                                  linkProvider: itemModel.linkProvider,
                                  cardMenu: relatedRowsMenu,
                                  pendingShelves: itemModel.pendingRelatedShelfTitles,
                                  onSectionFocused: leaveHero)
        .detailFocusSection("related")
      MediaItemInfoColumns(mediaItem: itemModel.mediaItem,
                           externalMetadata: itemModel.externalMetadata,
                           onSectionFocused: leaveHero)
        .detailFocusSection("about")
    }
  }

  @ViewBuilder
  private var pageBackground: some View {
#if os(tvOS)
    if itemModel.itemLoaded {
      // Passing `heroPhase` itself, not `heroPhase.isHeroOnScreen` — the latter would
      // read the value here, inside `MediaItemView.body`, and reintroduce the exact
      // dependency `MediaItemHeroPhase` exists to avoid.
      MediaItemHeroBackdrop(mediaItem: itemModel.mediaItem,
                            trailer: trailer,
                            phase: heroPhase)
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
/// TODO IT MUST BE SAME IDENTICAL PICTURE - WIDE ONE. TVOS, IOS, MACOS, etc
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
/// Snaps the page to one of two resting positions: hero at the top, or the first
/// content section at the top. Nothing in between is reachable, which is the whole
/// point — left alone, the focus engine scrolls only far enough to reveal whichever
/// element just took focus, an offset that is a function of that element's geometry
/// rather than of which half of the page you are in. That is why the page used to
/// stop twenty pixels down and stay there.
private struct MediaItemFoldSnappingBehavior: ScrollTargetBehavior {
  var aboveFold: Bool
  var showcaseHeight: CGFloat

  func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
    // Before the hero has been measured there is no fold to snap to.
    guard showcaseHeight > 0 else { return }

    // Two positions, chosen by which page owns focus — nothing else.
    //
    // Apple's landing-page sample guards this with distance thresholds ("above the
    // fold and not travelling far enough down — leave it be"). Those are written for
    // a page the user *swipes*: a small target means they barely moved. On a page
    // that moves by focus the first thing below the fold is only a short scroll away
    // — it is already peeking under the hero — so every crossing landed inside the
    // leave-it-be zone and never snapped. Sections further down (ratings, cast) did
    // snap, which is exactly how this was spotted.
    if aboveFold {
      FocusLog.snapped(from: target.rect.origin.y, to: 0, aboveFold: true)
      target.rect.origin.y = 0
      return
    }

    // The two resting positions govern **the fold**, not the whole page. Applied to
    // every scroll below it, this pinned the page at `showcaseHeight` forever: focus
    // moved to the cast rail, the snap yanked the offset from 1295 back to 816, the
    // rail left the screen and focus bounced straight back out — so nothing below the
    // vote buttons was reachable at all. Once the page has travelled past the first
    // section, the focus engine's own target is the correct one.
    guard target.rect.origin.y < showcaseHeight else { return }
    FocusLog.snapped(from: target.rect.origin.y, to: showcaseHeight, aboveFold: false)
    target.rect.origin.y = showcaseHeight
  }
}

/// Overlay-header title logo (`docs/archive/plans/detail-page-choreography.md` phase 2).
/// Fades in once focus has left the hero, fades out on return — matching the same
/// binary `isHeroOnScreen` clock as `MediaItemHeroBackdrop`'s wash and
/// `MediaItemHeroView`'s `chromeAlpha`, rather than the continuous scroll-progress the
/// plan's prose describes: continuous per-frame scroll tracking was deliberately
/// deleted from this page (see `MediaItemHeroPhase`) because it re-ran the whole page
/// body every scroll frame. This is the binary-model translation of the same idea —
/// once the hero's own title/logo has faded out, this one fades in to replace it as an
/// orientation cue while scrolling through sections.
///
/// Deliberately does not include the plan's other phase-2 bullet (moving the season
/// rail into this overlay) — that couples into `SeasonsRailView`'s own internals and
/// is left for a separate pass. iOS/macOS are also deferred: both platforms already
/// hide this page's real navigation title (`MediaItemView.body`'s
/// `.platformNavigationTitle("")`), and swapping a system nav title in only for this
/// page would reopen that decision rather than extend it.
private struct MediaItemTitleLogoHeader: View {
  var phase: MediaItemHeroPhase
  var titleLogoURL: URL?
  var title: String

  var body: some View {
    // Centred, not leading: once the hero's own bottom-leading title block has faded
    // out, a logo still pinned to the left edge reads as a leftover from it. Centred
    // it reads as the page's title bar, which is what it now is.
    VStack(spacing: 0) {
      content
        .padding(.horizontal, MediaItemLayout.horizontalInset)
        .padding(.top, Self.topPadding)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: Self.bandHeight, alignment: .top)
    .background(scrim)
    .frame(maxWidth: .infinity, alignment: .top)
    .opacity(phase.isHeroOnScreen ? 0 : 1)
    .allowsHitTesting(false)
    .animation(.easeOut(duration: 0.3), value: phase.isHeroOnScreen)
  }

  @ViewBuilder
  private var content: some View {
    if let titleLogoURL {
      AsyncImage(url: titleLogoURL) { image in
        image
          .resizable()
          .scaledToFit()
      } placeholder: {
        Color.clear
      }
      .frame(maxWidth: Self.logoMaxWidth, maxHeight: Self.logoMaxHeight, alignment: .center)
    }
    // No lettered fallback. Spelling the title out here reads as a caption stuck to
    // the top of the page rather than as the title bar this is meant to be — artwork
    // for every title is the plan instead.
  }

  /// Independent of `MediaItemHeroBackdrop`, which is a fixed full-screen layer behind
  /// everything and may itself carry little visual weight by the time a below-fold
  /// section this far down is showing — this scrim is what actually keeps the logo
  /// legible over whatever section content has scrolled underneath it.
  private var scrim: some View {
    LinearGradient(stops: [
      .init(color: .black.opacity(1), location: 0),
      .init(color: .black.opacity(0.5), location: 0.7),
      .init(color: .clear, location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

  private static let topPadding: CGFloat = 48
  private static let bandHeight: CGFloat = 160
  private static let logoMaxWidth: CGFloat = 320
  private static let logoMaxHeight: CGFloat = 100
}

/// The name of the detail section a view sits in, for focus tracing. Set once per
/// section by `detailFocusSection(_:)` where the page is composed, so the individual
/// section views do not each have to know (or repeat) their own name.
private struct DetailSectionNameKey: EnvironmentKey {
  static let defaultValue = "detail-section"
}

extension EnvironmentValues {
  var detailSectionName: String {
    get { self[DetailSectionNameKey.self] }
    set { self[DetailSectionNameKey.self] = newValue }
  }
}

/// Reports when a control inside a detail section takes focus.
struct MediaItemSectionFocusReporter: ViewModifier {
  let onSectionFocused: () -> Void
  @Environment(\.isFocused) private var isFocused
  @Environment(\.detailSectionName) private var section

  func body(content: Content) -> some View {
    content.onChange(of: isFocused) { _, focused in
      FocusLog.moved(section: section, element: "control", focused: focused)
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
  func detailFocusSection(_ name: String = "detail-section") -> some View {
#if os(tvOS)
    focusSection()
      .environment(\.detailSectionName, name)
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
