//
//  MediaItemHeroView.swift
//  KinoPubAppleClient
//

import SwiftUI
import AVKit
import AVFoundation
import Combine
import KinoPubUI
import KinoPubBackend

/// Loads the trailer alongside the artwork and reports when it is actually ready to
/// show, so the hero only swaps once there is something to swap to.
@MainActor
final class TrailerPreviewModel: ObservableObject {

  @Published private(set) var player: AVPlayer?
  @Published private(set) var isReady: Bool = false

  private var statusObservation: NSKeyValueObservation?
  private var endObserver: Any?
  private var startedURL: URL?
  /// False while the hero is scrolled off screen. Playback is gated on it rather than
  /// started unconditionally, so a trailer that becomes ready after the page has been
  /// scrolled past never starts decoding in the first place.
  private var isActive = true

  /// Plays the trailer muted behind the artwork. A repeat call for the URL already
  /// running is ignored, so a re-rendered hero doesn't restart it from the top.
  func start(url: URL) {
    guard startedURL != url else { return }
    teardown()
    startedURL = url

    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    player.isMuted = true
    // Nothing here is worth keeping the screen awake for — the real player is.
    player.preventsDisplaySleepDuringVideoPlayback = false
    // The artwork comes back at the end rather than the trailer looping.
    player.actionAtItemEnd = .pause
    self.player = player

    // Observed on the item: `\.currentItem?.status` through the player is a key path
    // through an optional and does not reliably deliver.
    statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
      let status = item.status
      Task { @MainActor in
        self?.handle(status: status)
      }
    }

    endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                        object: item,
                                                        queue: .main) { [weak self] _ in
      Task { @MainActor in
        self?.teardown()
      }
    }
  }

  /// Pauses rather than tears down when the hero scrolls away: the player stays
  /// warm so scrolling back up resumes mid-trailer, while the backdrop hides the
  /// layer and shows a blurred still. Stopping the decode is what keeps the seasons
  /// rail from stuttering under a live `AVPlayerLayer`.
  func setActive(_ active: Bool) {
    guard isActive != active else { return }
    isActive = active

    guard let player else { return }
    if active {
      if isReady { player.play() }
    } else {
      player.pause()
    }
  }

  private func handle(status: AVPlayerItem.Status) {
    switch status {
    case .readyToPlay:
      isReady = true
      if isActive { player?.play() }
    case .failed:
      // A trailer that won't load just leaves the artwork in place.
      teardown()
    default:
      break
    }
  }

  /// Hands the preview over to the full-screen presentation and back. It is the same
  /// `AVPlayer` either way — that is the whole point of the gesture, the trailer keeps
  /// running rather than starting over — so all that changes is the sound and whether
  /// it is worth keeping the screen awake for.
  func setFullScreen(_ fullScreen: Bool) {
    guard let player else { return }
    player.isMuted = !fullScreen
    player.preventsDisplaySleepDuringVideoPlayback = fullScreen
    if fullScreen, isActive, isReady {
      player.play()
    }
  }

  /// Drops back to the artwork and forgets what was playing, so leaving the page and
  /// coming back starts the trailer over.
  func stop() {
    teardown()
    startedURL = nil
  }

  private func teardown() {
    player?.pause()
    isReady = false
    statusObservation?.invalidate()
    statusObservation = nil
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
      self.endObserver = nil
    }
    player = nil
  }

  deinit {
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    statusObservation?.invalidate()
  }
}

/// The trailer as a bare `AVPlayerLayer`. `VideoPlayer` brings the transport UI and
/// its own focus behaviour along, and fits the video inside the frame — behind a
/// title it has to fill the hero and stay out of the way instead.
struct TrailerVideoLayer {
  let player: AVPlayer
  /// `.resizeAspectFill` behind the title so the trailer fills the hero; the
  /// full-screen presentation asks for `.resizeAspect` so nothing is cropped away.
    var gravity: AVLayerVideoGravity = .resizeAspect
}

#if os(macOS)
extension TrailerVideoLayer: NSViewRepresentable {
  func makeNSView(context: Context) -> TrailerLayerHostView {
    TrailerLayerHostView(player: player, gravity: gravity)
  }

  func updateNSView(_ view: TrailerLayerHostView, context: Context) {
    view.playerLayer.player = player
    view.playerLayer.videoGravity = gravity
  }
}

/// The `AVPlayerLayer` *is* the view's backing layer — the AppKit twin of the
/// `layerClass` override the UIKit side uses.
///
/// It used to be a sublayer of a plain `CALayer`, with `layout()` copying `bounds`
/// onto it by hand. Assigning `layer` after `wantsLayer` leaves the view host-backed
/// rather than layer-backed, so that `layout()` did not reliably fire on resize and
/// the video kept whatever frame it was first given — which is why aspect-fill looked
/// like it was fitting: the layer was simply the wrong size for the hero. A backing
/// layer tracks bounds itself, and there is nothing left to keep in sync.
final class TrailerLayerHostView: NSView {

  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

  override func makeBackingLayer() -> CALayer {
    AVPlayerLayer()
  }

  init(player: AVPlayer, gravity: AVLayerVideoGravity) {
    super.init(frame: .zero)
    wantsLayer = true
    // Without this the layer animates its way to every new size as the window resizes.
    layerContentsRedrawPolicy = .duringViewResize
    playerLayer.player = player
    playerLayer.videoGravity = gravity
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
#else
extension TrailerVideoLayer: UIViewRepresentable {
  func makeUIView(context: Context) -> TrailerLayerHostView {
    TrailerLayerHostView(player: player, gravity: gravity)
  }

  func updateUIView(_ view: TrailerLayerHostView, context: Context) {
    view.playerLayer.player = player
    view.playerLayer.videoGravity = gravity
  }
}

final class TrailerLayerHostView: UIView {

  override class var layerClass: AnyClass { AVPlayerLayer.self }

  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

  init(player: AVPlayer, gravity: AVLayerVideoGravity) {
    super.init(frame: .zero)
    playerLayer.player = player
    playerLayer.videoGravity = gravity
    isUserInteractionEnabled = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
#endif

#if os(tvOS)
/// Full-screen stack pinned behind the detail `ScrollView` — the Apple TV shape.
///
/// One wide still with a material over it, masked by a gradient — Apple's documented
/// tvOS above/below-the-fold treatment, built entirely in SwiftUI.
///
/// Two earlier versions of this are worth remembering. The first cross-faded a
/// *different* asset (a downsampled poster, separately blurred) under the sharp one,
/// which is why the colours visibly disagreed mid-wash. The second fixed the colours
/// by dropping to a `UIVisualEffectView` bridge, on my claim that SwiftUI cannot
/// animate a material — it can: you animate the gradient mask in front of it, not the
/// material itself. What must never come back is fading a material by `.opacity()`,
/// which draws the same full-strength effect semi-transparently instead of weakening
/// it.
/// Ambient trailer is intentionally off (policy: no blur-over-video; scrims +
/// still until a dedicated hero pass). `trailer` is kept for a later pass /
/// Up-to-fullscreen when ambient returns.
struct MediaItemHeroBackdrop: View {

  var mediaItem: MediaItem
  @ObservedObject var trailer: TrailerPreviewModel
  /// Read directly from `phase` inside this view's own `body` (never pre-extracted by
  /// the caller) — that is what makes `MediaItemHeroPhase` changes re-render only this
  /// view instead of the whole page. See `MediaItemHeroPhase`.
  var phase: MediaItemHeroPhase

  /// 0 = hero sharp; 1 = below-fold wash. **Section state, not scroll offset.**
  ///
  /// This used to be scrubbed per-frame from the scroll offset (`offset / 600`), which
  /// made the blur a function of how far the page happened to scroll — and the page only
  /// scrolls as far as it needs to reveal the next focusable thing. A tall season rail
  /// forced a long scroll and a full wash; a short ratings row (a movie's first section)
  /// forced a short one and almost none. That is why the blur looked "tied to episodes"
  /// and why it arrived in visible steps. It also re-ran this whole page's body on every
  /// scroll frame, re-rendering every shelf underneath.
  ///
  /// Now it is binary and driven by whether focus is in the hero section — the SwiftUI
  /// gradient layers below still key off it directly; the material wash itself is driven
  /// by the same `isHeroOnScreen` passed straight into the UIKit representable, which
  /// owns its own transition timing.
  private var effectiveWash: CGFloat {
    phase.isHeroOnScreen ? 0 : 1
  }

  var body: some View {
    ZStack {
      Color.KinoPub.background

      // Loading placeholder only — a cheap blurred wash from the *small* poster
      // (120×180 raster) until the real wide still decodes. Do not `drawingGroup`
      // +scale a full-bleed buffer: that path plus eager Home shelves was blowing
      // past 1.5GB (CVPixelBuffer -6680).
      blurredPoster

      // One wide still, with the material laid over it and *masked* by a gradient
      // whose stop opacities are what animate. This is Apple's documented tvOS
      // above/below-the-fold treatment, and it replaces the `UIVisualEffectView`
      // bridge that used to live here.
      //
      // I had told you SwiftUI has no animatable material intensity and dropped to
      // UIKit for it. That was wrong: you do not animate the material, you animate
      // the mask in front of it — the docs call this out explicitly, "rather than
      // swapping out the mask view, you achieve a smooth animation". Worth being
      // precise about what it does, though: this changes how much of the frame the
      // material *covers*, not the blur radius. Above the fold the material fades
      // out toward the top and the still reads sharp; below the fold it covers the
      // whole frame and the still is fully washed.
      heroStill
        .overlay { foldMaterial }

      topGradient
        .opacity(1 - effectiveWash)

      bottomScrim
      titleScrim
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .ignoresSafeArea()
    .animation(.easeOut(duration: 0.35), value: phase.isHeroOnScreen)
  }

  /// The single source of every pixel behind this page — sharp above the fold,
  /// washed below it. Prefer `/wide/`, falling back to `medium` rather than `big` so
  /// a multi-MB 4K poster is never decoded into a full-screen layer.
  private var heroStill: some View {
    CachedRemoteImage(url: URL(string: heroStillURL), contentMode: .fill)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
  }

  /// Material over the still, revealed by a gradient mask. Only the stop opacities
  /// change between states, which is what keeps the transition smooth.
  private var foldMaterial: some View {
    let belowFold = !phase.isHeroOnScreen
    return Rectangle()
      .fill(.regularMaterial)
      .mask {
        LinearGradient(stops: [
          .init(color: .black, location: 0.25),
          .init(color: .black.opacity(belowFold ? 1 : 0.3), location: 0.375),
          .init(color: .black.opacity(belowFold ? 1 : 0), location: 0.5)
        ], startPoint: .bottom, endPoint: .top)
      }
  }

  /// Scale is derived from the real container so a portrait buffer still covers
  /// a 16:9 screen — a fixed `scaleEffect` of 10 left ~1200pt of width and the
  /// sides fell back to the page colour.
  private var blurredPoster: some View {
    GeometryReader { geo in
      let scale = max(geo.size.width / Self.blurBuffer.width,
                      geo.size.height / Self.blurBuffer.height) * 1.05

      CachedRemoteImage(url: URL(string: mediaItem.posters.small), contentMode: .fill)
        .frame(width: Self.blurBuffer.width, height: Self.blurBuffer.height)
        .clipped()
        .blur(radius: Self.blurRadius, opaque: true)
        .saturation(1.4)
        .scaleEffect(scale)
        .frame(width: geo.size.width, height: geo.size.height)
        .clipped()
    }
  }

  private var heroStillURL: String {
    // Prefer `/wide/` when present; fall back to `medium` rather than `big` so we
    // don't decode a multi‑MB 4K poster into a full-screen layer on the simulator.
    mediaItem.posters.wideURL ?? mediaItem.posters.medium
  }

  /// Very light black wash from the top edge down to about mid-frame — enough to
  /// settle the status area without dulling the still. Fades out with the hero.
  private var topGradient: some View {
    LinearGradient(stops: [
      .init(color: .black.opacity(0.32), location: 0),
      .init(color: .black.opacity(0.12), location: 0.28),
      .init(color: .clear, location: 0.55)
    ], startPoint: .top, endPoint: .bottom)
  }

  /// Soft shade under the title and buttons. Stronger under the material wash so
  /// section text sits cleanly. Full width: unlike a narrow single-column hero, our
  /// tvOS/macOS text runs the whole bottom edge (title + actions on the leading side,
  /// synopsis / credits / metadata filling the trailing side — `MediaItemHeroView.content`),
  /// so the right column needs the same floor as the left, not a lighter one.
  private var bottomScrim: some View {
    let bottom = 0.35 + (0.25 * effectiveWash)
    return LinearGradient(stops: [
      .init(color: .clear, location: 0),
      .init(color: .clear, location: 0.2),
      .init(color: .black.opacity(0.3 + 0.1 * effectiveWash), location: 0.38),
      .init(color: .black.opacity(bottom), location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

  /// Extra contrast anchored where the title actually sits (bottom-leading — Rivulet's
  /// diagonal scrim, adapted). Their version can fade all the way to clear at the
  /// opposite corner because their text is a single narrow left-hand column; ours runs
  /// full width, so `bottomScrim` above still has to hold the floor for the trailing
  /// (right) side on its own. This only ADDS weight over the title block itself — the
  /// largest, least-shadowed element (a title-logo image has no `heroTextShadow()` of
  /// its own) — and is gone by the time it reaches the trailing edge.
  /// Values are Rivulet's, measured rather than guessed: their `ScrimGradientView` is
  /// `0.92 → 0.55 → clear` at stops `0 / 0.45 / 1`, bottom-leading → top-trailing. Ours
  /// shipped at `0.5 → 0.18 → clear` on `0 / 0.5 / 1` — roughly **half** the darkness at
  /// the anchor and a **third** at the midpoint, which over a bright backdrop reads as
  /// no scrim at all. It was never missing, just far too weak to see. Matched now.
  private var titleScrim: some View {
    LinearGradient(stops: [
      .init(color: .black.opacity(min(1, 0.92 + 0.08 * effectiveWash)), location: 0),
      .init(color: .black.opacity(0.55), location: 0.45),
      .init(color: .clear, location: 1)
    ], startPoint: .bottomLeading, endPoint: .topTrailing)
  }

  /// Portrait small, rasterised once. Scale is computed at layout time to cover
  /// the screen on both axes.
  private static let blurBuffer = CGSize(width: 120, height: 180)
  private static let blurRadius: CGFloat = 12
}

#endif // SEEMS VERY RESOURCEFUL FOR WHAT?? I

/// The item page's secondary actions, as menu content. Shared so the same list can be
/// a circle in the hero row (tvOS) or a toolbar item (iPhone / Mac) without either
/// copy drifting from the other.
struct MediaItemOverflowMenu: View {

  var isSeries: Bool
  var isWatched: Bool
  var isBookmarked: Bool
  var onWatchedToggle: () -> Void
  var onClearFromContinueWatching: () -> Void
  var onBrowseWatchlist: (() -> Void)?

  var body: some View {
    Button(role: .destructive, action: onClearFromContinueWatching) {
      Label("Remove from Recently Watched", systemImage: "trash")
    }

    if isWatched {
      Button(action: onWatchedToggle) {
        Label("Mark as New", systemImage: "eye")
      }
    }

    if isSeries, isBookmarked, let onBrowseWatchlist {
      Button(action: onBrowseWatchlist) {
        Label("Browse My Watchlist", systemImage: "rectangle.grid.3x2")
      }
    }
  }
}

/// Full-bleed artwork that gives way to the trailer, with the title, metadata and
/// actions laid over it — the shape the Apple TV app uses. On iPhone the picture keeps
/// its own 16:9 band and the chrome sits under it instead.
struct MediaItemHeroView: View {

  var mediaItem: MediaItem
  /// The page's focus target — the primary action claims it, so a page whose content
  /// lands late still opens at the top rather than wherever the focus engine drifted.
  @FocusState.Binding var focus: MediaItemFocusTarget?
  /// Owned by the page so the same player can sit in the pinned tvOS backdrop and in
  /// the hero's Up-to-fullscreen gesture.
  @ObservedObject var trailer: TrailerPreviewModel
  /// Drives trailer pause / the blurred still on the pinned backdrop. The hero never
  /// leaves the hierarchy on scroll, so this is measured rather than `onDisappear`.
  /// Read/written directly through `phase` inside this view's own `body` — never
  /// pre-extracted by the caller. See `MediaItemHeroPhase`.
  var phase: MediaItemHeroPhase
  var linkProvider: NavigationLinkProvider
  var isWatched: Bool
  var isBookmarked: Bool
  var folders: [Bookmark]
  var folderIDsContainingItem: Set<Int>
  var onWatchedToggle: () -> Void
  /// Bulk form of the above: marks every episode of the season the primary button is
  /// pointing at. Nil collapses the checkmark back to a plain single-episode toggle.
  var onSeasonWatchedToggle: ((Season) -> Void)? = nil
  var onFolderToggle: (Bookmark) -> Void
  var onCreateFolder: ((String) -> Void)? = nil
  var onClearFromContinueWatching: () -> Void = {}
  /// Opens the Saved / watchlist tab — same destination as the CW long-press action.
  var onBrowseWatchlist: (() -> Void)? = nil
  /// Series watchlist toggle for the shared context menu (not the hero checkmark).
  var isInWatchlist: Bool = false
  var onToggleWatchlist: (() -> Void)? = nil
  /// TMDB / Kinopoisk title logo when enrichment supplied one.
  var titleLogoURL: URL? = nil
  /// Certification from enrichment ("TV-14", "16+"). Rendered as one more capability
  /// chip in the metadata row — the item payload has no rating of its own.
  var ageRating: String? = nil
  /// False until external metadata settles. While false, the title slot stays empty
  /// (optimistic: a logo is expected). Defaults to `true` so previews without the
  /// enrichment pipeline still show the lettered title.
  var externalMetadataLoaded: Bool = true

  /// tvOS only: the Up gesture lifts the muted inline preview into a real full-screen
  /// player. Kept here so the same view that owns the preview owns its promotion.
  @State private var isTrailerFullScreen = false
  @State private var showNewFolderAlert = false
  @State private var newFolderName = ""

  /// Opt-in, off by default. Read as `@AppStorage` so flipping it in Settings redraws
  /// the metadata row without leaving the page.
  @AppStorage(MediaItemDisplayPreferences.showAgeRatingBadgeKey)
  private var showsAgeRatingBadge = false

  @Environment(\.openURL) private var openURL
  @EnvironmentObject private var navigationState: NavigationState

  private var isSeries: Bool {
    !(mediaItem.seasons?.isEmpty ?? true)
  }

  /// Films and series both get the checkmark, in progress or not started. It only
  /// disappears once there is nothing left to mark — a finished title reverses through
  /// Mark as New in More instead.
  private var showsWatchedButton: Bool {
    !isWatched
  }

  /// Fade title/actions when focus leaves the hero — never hard-zero. Opacity 0 on the
  /// whole hero dropped Play/More from the focus graph, so Up from seasons could
  /// not return (Rivulet keeps a focusable return path; we keep the buttons alive).
  ///
  /// Keyed to the same section state as `MediaItemHeroBackdrop.effectiveWash`, so chrome
  /// and backdrop can never disagree — they previously did, because this read the raw
  /// per-frame scroll value while the backdrop read a guarded one.
  private var chromeAlpha: CGFloat {
#if os(tvOS)
    phase.isHeroOnScreen ? 1 : 0.35
#else
    1
#endif
  }

  var body: some View {
    platformBody
      // Moved down from the page level: this is the one view that already reads
      // `phase.isHeroOnScreen` in its own body (via `chromeAlpha`/`visibilityProbe`),
      // so adding the trailer side effect here costs nothing extra structurally —
      // doing it at `MediaItemView` would have re-coupled the page's body to the value.
      .onChange(of: phase.isHeroOnScreen) { _, onScreen in
        trailer.setActive(onScreen)
      }
  }

  @ViewBuilder
  private var platformBody: some View {
#if os(tvOS)
    // Fills the hero slideshow slide; bottom-aligned over the pinned backdrop.
    // Force dark so `Color.primary` / scores / plot stay light over the artwork —
    // same always-readable chrome as the Apple TV app, without hard-coding whites.
    content
      .opacity(chromeAlpha)
      .animation(.easeOut(duration: 0.25), value: chromeAlpha)
      .environment(\.colorScheme, .dark)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
      // The same muted preview, promoted to sound and full screen without restarting.
      // Menu on the remote dismisses it — no chrome of our own over the picture.
      .fullScreenCover(isPresented: $isTrailerFullScreen, onDismiss: { trailer.setFullScreen(false) }) {
        fullScreenTrailer
      }
      .modifier(MediaCardContextMenuModifier(entries: contextMenuEntries))
#else
    // 16:9 is the floor rather than the height, so a narrow window or a phone grows
    // the band instead of clipping the buttons off the top of it.
    //
    // Backdrop stays in the ambient scheme so the bottom seam still blends into the
    // page colour; only the overlay chrome is forced dark.
    ZStack(alignment: .bottomLeading) {
      Color.clear
        .aspectRatio(16 / 9, contentMode: .fit)

      content
        .environment(\.colorScheme, .dark)
    }
    .frame(maxWidth: .infinity, alignment: .bottomLeading)
    .background {
      ZStack {
        scrollingBackdrop
        scrollingScrim
      }
    }
    .clipped()
    .background(visibilityProbe)
    .modifier(MediaCardContextMenuModifier(entries: contextMenuEntries))
#endif
  }

  /// Same builder as Home / Library cards — Play, library, watched, hide, DEBUG art URLs.
  private var contextMenuEntries: [MediaCardContextEntry] {
    let card = MediaCard(
      id: mediaItem.id,
      posterURL: mediaItem.posters.medium,
      title: mediaItem.localizedTitle,
      subtitle: mediaItem.originalTitle,
      scores: MediaScores(mediaItem),
      backdropURL: mediaItem.posters.wideURL ?? mediaItem.posters.big,
      metaLine: mediaItem.metadataLine,
      overview: mediaItem.plot,
      itemID: mediaItem.id,
      video: isSeries ? nil : 1,
      isWatched: isWatched,
      isSeries: isSeries,
      isInWatchlist: isInWatchlist
    )
    let folderOptions = folders.map {
      MediaCardContextMenus.BookmarkFolderOption(
        id: $0.id,
        title: $0.title,
        isContaining: folderIDsContainingItem.contains($0.id)
      )
    }
    return MediaCardContextMenus.entries(
      for: card,
      surface: .banner,
      bookmarkFolders: folderOptions,
      onPlay: {
        if let route = linkProvider.player(for: playTarget) as? Route {
          navigationState.push(route)
        }
      },
      onGoToTitle: nil,
      onToggleWatchlist: isSeries ? onToggleWatchlist : nil,
      onToggleBookmarkFolder: { folderID in
        guard let folder = folders.first(where: { $0.id == folderID }) else { return }
        onFolderToggle(folder)
      },
      onCreateBookmarkFolder: onCreateFolder == nil
        ? nil
        : {
          newFolderName = ""
          showNewFolderAlert = true
        },
      onToggleWatched: onWatchedToggle,
      onHide: onClearFromContinueWatching,
      onOpenImageURL: { openURL($0) },
      debugImageURLs: debugArtworkURLs
    )
  }

  /// Wide backdrop first, then title-logo art when TMDB supplied one.
  private var debugArtworkURLs: [URL] {
    var urls: [URL] = []
    var seen = Set<String>()
#if os(tvOS)
    let wide = mediaItem.posters.wideURL ?? mediaItem.posters.big
    if !wide.isEmpty, seen.insert(wide).inserted, let url = URL(string: wide) {
      urls.append(url)
    }
#else
    if let primary = backdropCandidates.first, seen.insert(primary.absoluteString).inserted {
      urls.append(primary)
    }
#endif
    if let titleLogoURL, seen.insert(titleLogoURL.absoluteString).inserted {
      urls.append(titleLogoURL)
    }
    return urls
  }

#if os(tvOS)
  /// The trailer with nothing on it: black surround, aspect-fit so nothing is cropped,
  /// and the preview's own player so it carries on from where the hero left it.
  @ViewBuilder
  private var fullScreenTrailer: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      if let player = trailer.player {
        TrailerVideoLayer(player: player, gravity: .resizeAspect)
          .ignoresSafeArea()
      }
    }
    .onAppear { trailer.setFullScreen(true) }
  }
#endif

  // MARK: - Background

#if !os(tvOS)
  /// The hero sits in a plain `VStack` inside the page's `ScrollView`, so it is never
  /// removed from the hierarchy and `onDisappear` only fires when the whole page goes
  /// away — not when the hero scrolls off the top. Its frame in the scroll view's own
  /// space is what actually says whether it is on screen.
  private var visibilityProbe: some View {
    GeometryReader { proxy in
      let frame = proxy.frame(in: .named(MediaItemLayout.scrollSpace))
      Color.clear
        .onChange(of: frame.minY >= -Self.onScreenSlop) { _, onScreen in
          phase.isHeroOnScreen = onScreen
        }
    }
  }

  /// wide → big → medium. Same chain as Home banners — list/detail payloads differ and
  /// a `/wide/` derivation frequently 404s, so one URL is not enough. See
  /// `FallbackRemoteImage`.
  private var backdropCandidates: [URL] {
    var seen = Set<String>()
    var urls: [URL] = []
    for raw in [mediaItem.posters.wideURL, mediaItem.posters.big, mediaItem.posters.medium]
      .compactMap({ $0 }) where !raw.isEmpty && seen.insert(raw).inserted {
      if let url = URL(string: raw) { urls.append(url) }
    }
    return urls
  }

  @ViewBuilder
  private var scrollingBackdrop: some View {
    ZStack {
      FallbackRemoteImage(urls: backdropCandidates, contentMode: .fill)
        .onAppear {
#if DEBUG
          let list = backdropCandidates.map(\.absoluteString).joined(separator: " | ")
          print("[Artwork] hero id=\(mediaItem.id) candidates=\(list)")
#endif
        }

      if let player = trailer.player, trailer.isReady {
        TrailerVideoLayer(player: player)
          .allowsHitTesting(false)
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .animation(.easeInOut(duration: 0.6), value: trailer.isReady)
  }

  /// Barely there, the way the Apple TV app leaves its hero video alone: clear for
  /// most of the frame, a light shade under the text, and the background colour only
  /// at the last few percent — without that the hero would meet the page on a visible
  /// seam. What carries the text is `heroTextShadow` on the type itself, not a slab
  /// over the picture.
  private var scrollingScrim: some View {
    LinearGradient(stops: [
      .init(color: .clear, location: 0),
      .init(color: .clear, location: 0.62),
      .init(color: Color.KinoPub.background.opacity(0.32), location: 0.82),
      .init(color: Color.KinoPub.background.opacity(0.9), location: 0.97),
      .init(color: Color.KinoPub.background, location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }
#endif

  // MARK: - Foreground

  /// Wide screens (tvOS / Mac): two columns — title + actions | everything written.
  /// The third "starring" column is gone; its lines moved under the synopsis.
  /// Phone keeps a single stacked column, with the metadata row above the buttons.
  private var content: some View {
#if os(iOS)
    VStack(alignment: .leading, spacing: Self.contentSpacing) {
      titleBlock
        .heroTextShadow()

      actions
        .padding(.top, Self.actionsGap)

      detailColumn
        .padding(.top, Self.actionsGap)
    }
    .padding(.horizontal, Self.horizontalInset)
    .padding(.bottom, Self.bottomInset)
    .frame(maxWidth: .infinity, alignment: .leading)
#else
    HStack(alignment: .bottom, spacing: Self.columnGutter) {
      // Fixed, not proportional: the title block and the action stack are a known
      // size, and letting them share the width evenly with the prose left the
      // synopsis in a narrow ravine on a wide window.
      leadingColumn
        .frame(width: Self.leadingWidth, alignment: .leading)

      detailColumn
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, Self.horizontalInset)
    .padding(.bottom, Self.bottomInset)
    .frame(maxWidth: .infinity, alignment: .leading)
#endif
  }

  /// Logo / title, then the action stack — left column on wide layouts. The metadata
  /// row moved across to head the written column, the way the reference layout has it.
  private var leadingColumn: some View {
    VStack(alignment: .leading, spacing: Self.contentSpacing) {
      // Shadowed on its own, with the actions left out of it: the buttons carry their
      // own material, and a drop shadow under one that scales on focus is an extra
      // offscreen pass on every frame of the animation.
      titleBlock
        .heroTextShadow()

      // Actions sit with the title so Up from Play is a dead end → fullscreen trailer.
      // Everything written is the sibling column (or below on phone), not above the row.
      actions
        .padding(.top, Self.actionsGap)
    }
  }

  /// Synopsis first, then who made it, then the facts. What someone is deciding on is
  /// what the film is about — year, genres and the score are what they check after,
  /// so they sit at the foot of the column rather than heading it.
  private var detailColumn: some View {
    VStack(alignment: .leading, spacing: Self.contentSpacing) {
      MediaItemPlotView(title: mediaItem.localizedTitle, plot: mediaItem.plot, focus: $focus)
      credits
      metadata
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .heroTextShadow()
  }

  @ViewBuilder
  private var titleBlock: some View {
    // Optimistic hold: do not paint letters until enrichment has settled and any
    // logo URL has either drawn or failed. Bottom-aligned column keeps meta/actions put.
    // 150ms opacity fade — same transaction pattern as the wide still.
    Group {
      if !externalMetadataLoaded {
        EmptyView()
      } else if let titleLogoURL {
        ArtworkImage(
          url: titleLogoURL,
          transaction: Transaction(animation: .easeOut(duration: 0.15))
        ) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
              .frame(maxWidth: Self.logoMaxWidth, maxHeight: Self.logoMaxHeight, alignment: .leading)
              .transition(.opacity)
          case .failure:
            titleTextBlock
              .transition(.opacity)
          case .empty:
            EmptyView()
          }
        }
      } else {
        titleTextBlock
          .transition(.opacity)
      }
    }
    .animation(.easeOut(duration: 0.15), value: externalMetadataLoaded)
  }

  private var titleTextBlock: some View {
    VStack(alignment: .leading, spacing: Self.contentSpacing) {
      // Above the localized title, as an eyebrow: it is the same title, not a second
      // piece of information, so it leads into the big one rather than trailing it.
      if mediaItem.originalTitle != mediaItem.localizedTitle {
        Text(mediaItem.originalTitle)
          .font(Self.secondaryFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
      }

      Text(mediaItem.localizedTitle)
        .font(Self.titleFont)
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(2)
    }
  }

  /// Heads the written column: the score, when and how long, then the capability
  /// chips. Whatever is drawn here is the same component the posters wear — a title
  /// scores the same wherever it is shown, so it should not be spelled two ways.
  private var metadata: some View {
    HStack(spacing: Self.metaSpacing) {
      if FeatureFlags.combinedRatingEnabled {
        if let rating = MediaScores(mediaItem).aggregate {
          RatingBadgeView(rating: rating)
        }
      } else {
        // No aggregate: each score keeps its own logo rather than becoming one number.
        MediaScoresView(MediaScores(mediaItem))
      }

      let releaseLine = mediaItem.releaseLine
      if !releaseLine.isEmpty {
        Text(releaseLine)
          .lineLimit(1)
      }

      // Certification only when it was asked for — see `MediaItemDisplayPreferences`.
      let badges = MediaCapabilityBadges.from(item: mediaItem,
                                              ageRating: showsAgeRatingBadge ? ageRating : nil)
      if !badges.isEmpty {
        MediaCapabilityBadgesView(badges: badges, mode: .detail)
      }
    }
    .font(Self.secondaryFont)
    .foregroundStyle(Self.metaStyle)
  }

  /// Under the synopsis: what kind of thing it is and where it is from, then who is
  /// in it. Labels greyed, names picked out. The phone has no room for a cast list
  /// over the artwork — the detail sections below carry the full one anyway.
  @ViewBuilder
  private var credits: some View {
    if !genreCountryLine.isEmpty || showsCreditNames {
      VStack(alignment: .leading, spacing: Self.creditLineSpacing) {
        if !genreCountryLine.isEmpty {
          Text(genreCountryLine)
            .foregroundStyle(Color.KinoPub.subtitle)
        }

        if showsCreditNames {
          ForEach(creditLines, id: \.role) { line in
            Text(creditLine(line))
          }
        }
      }
      .font(Self.secondaryFont)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// Cast and director are wide-layout only.
  private var showsCreditNames: Bool {
#if os(iOS)
    false
#else
    !creditLines.isEmpty
#endif
  }

  /// One run of attributed text rather than two concatenated `Text`s: the styling
  /// overloads that return `Text` are either iOS 17 or deprecated, and the label has
  /// to flow into the names on the same line anyway.
  private func creditLine(_ line: (role: String, names: String)) -> AttributedString {
    var label = AttributedString(line.role.localized + " ")
    label.foregroundColor = Color.KinoPub.subtitle

    var names = AttributedString(line.names)
    names.foregroundColor = Color.KinoPub.text
    names.font = Self.secondaryFont.weight(.medium)

    return label + names
  }

  /// Genres and country carry no labels — the words say what they are, and a "Genre:"
  /// in front of them is the kind of form-field caption the Apple TV app never shows.
  /// Genres lead, because that is what someone is deciding on.
  private var genreCountryLine: String {
    var parts: [String] = []
    let genres = mediaItem.genreNames.prefix(Self.genreLimit)
    if !genres.isEmpty { parts.append(genres.joined(separator: ", ")) }
    let countries = mediaItem.countryNames.prefix(Self.countryLimit)
    if !countries.isEmpty { parts.append(countries.joined(separator: ", ")) }
    return parts.joined(separator: " · ")
  }

  /// A handful of leads and whoever directed it — the whole cast is what the section
  /// further down the page is for. A series has no one director to name, so it gets
  /// the cast alone.
  ///
  /// Nobody stars in a stand-up set, a concert or a documentary, so those name no
  /// leads here at all — their people are a Credits card in the information table.
  /// `MediaPresentationProfile` owns which is which.
  private var creditLines: [(role: String, names: String)] {
    var lines: [(String, String)] = []
    let cast: [String] = mediaItem.presentation.showsHeroCastLine
      ? Array(mediaItem.castMembers.prefix(Self.creditNameLimit))
      : []
    if !cast.isEmpty {
      lines.append(("Starring", cast.joined(separator: ", ")))
    }
    if !isSeries {
      let directors = mediaItem.directorNames.prefix(Self.creditNameLimit)
      if !directors.isEmpty {
        // The same word the Credits card and the "More by…" shelf use — the hero read
        // "Director" over a title whose shelf below it said "More by This Creator".
        lines.append((mediaItem.presentation.authorCaptionKey,
                      directors.joined(separator: ", ")))
      }
    }
    return lines
  }

  /// Primary on its own row, secondaries as one row of identical circles underneath —
  /// the shape the reference layout uses. Nothing here competes with Play for width.
  private var actions: some View {
    VStack(alignment: .leading, spacing: Self.actionsRowGap) {
      primaryAction
#if os(tvOS)
        // Dead-end Up opens the trailer; Down lands on the circles, then scrolls on
        // into the content below. Scoped to the primary row: from the circles, Up is
        // a real move to Play and must not be swallowed.
        .onMoveCommand { direction in
          if direction == .up, trailer.player != nil, trailer.isReady {
            isTrailerFullScreen = true
          }
        }
#endif

      HStack(spacing: MediaActionMetrics.rowSpacing) {
        // Trailer leads the row, directly under Play: it is the other thing you can
        // watch, not another piece of state.
        if mediaItem.trailerURL != nil {
          trailerButton
        }
        // Three different questions, three different controls: am I following this,
        // where have I filed it, how far did I get. They were two controls wired to
        // the same folder menu, which made the first two indistinguishable.
        if isSeries, onToggleWatchlist != nil {
          watchlistButton
        }
        bookmarkButton
        if showsWatchedButton {
          watchedButton
        }
#if os(tvOS)
        // No toolbar on a TV — overflow stays in the row there and only there.
        moreButton
#endif
      }
    }
  }

  /// Bookmark folders — icon only. Fills once the title is in at least one folder.
  @ViewBuilder
  private var bookmarkButton: some View {
    folderMenuLabel {
      Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
            .font(MediaActionMetrics.labelFont)

//        .font(.system(size: MediaActionMetrics.circleIconPointSize, weight: .semibold))
    }
    .mediaActionCircleStyle()
    .focused($focus, equals: .bookmark)
    .accessibilityLabel("Bookmarks")
    .alert("New Folder", isPresented: $showNewFolderAlert) {
      TextField("Folder name", text: $newFolderName)
      Button("Create") {
        onCreateFolder?(newFolderName)
        newFolderName = ""
      }
      Button("Cancel", role: .cancel) { newFolderName = "" }
    }
  }

  /// Follow the series — `/v1/watching/togglewatchlist`, so new episodes turn up in
  /// Watchlist. Not bookmark folders, and not watched: `minus` rather than a second
  /// checkmark for the active state, because the checkmark next door means something
  /// else entirely.
  @ViewBuilder
  private var watchlistButton: some View {
    Button {
      onToggleWatchlist?()
    } label: {
      Image(systemName: isInWatchlist ? "minus" : "plus")
            .font(MediaActionMetrics.labelFont)

//        .font(.system(size: MediaActionMetrics.circleIconPointSize, weight: .semibold))
    }
    .mediaActionCircleStyle()
    .focused($focus, equals: .watchlist)
    .accessibilityLabel(isInWatchlist ? "Remove from Watchlist" : "Add to Watchlist")
  }

  /// Mark as watched. A film flips straight away; a series has to be asked which —
  /// the episode you are on, or the whole season it belongs to. Gone once everything
  /// is watched: there is nothing left to mark, and More carries Mark as New.
  @ViewBuilder
  private var watchedButton: some View {
    if let (season, episode) = mediaItem.primaryEpisode, onSeasonWatchedToggle != nil {
      Menu {
        Button(action: onWatchedToggle) {
          Label("\("Mark Episode Watched".localized) · S\(season.number), E\(episode.number)",
                systemImage: "checkmark")
        }
        Button {
          onSeasonWatchedToggle?(season)
        } label: {
          Label("\("Mark Season Watched".localized) · \(season.number)",
                systemImage: "checkmark.circle")
        }
      } label: {
        watchedGlyph
      }
      .mediaActionCircleStyle()
      .focused($focus, equals: .watched)
      .accessibilityLabel("Mark as Watched")
    } else {
      Button(action: onWatchedToggle) {
        watchedGlyph
      }
      .mediaActionPillStyle()
      .focused($focus, equals: .watched)
      .accessibilityLabel("Mark as Watched")
    }
  }

  private var watchedGlyph: some View {
    Image(systemName: "checkmark")
          .font(MediaActionMetrics.labelFont)
//      .font(.system(size: MediaActionMetrics.circleIconPointSize, weight: .semibold))
  }

  /// The trailer says what it is. It sits directly under Play, first in the row, as a
  /// labelled capsule rather than one more anonymous circle: the circles are all
  /// *state* — am I following this, where is it filed, how far did I get — and the
  /// trailer is the second thing on the page you can actually watch. A film glyph
  /// among four state glyphs read as a fifth toggle. Only present when there is one.
  @ViewBuilder
  private var trailerButton: some View {
    PlayerLink(route: linkProvider.trailerPlayer(for: mediaItem), item: mediaItem, mode: .trailer) {
      Label("Trailer", systemImage: "film")
        .font(MediaActionMetrics.labelFont)
    }
    .mediaActionPillStyle()
    .focused($focus, equals: .trailer)
  }

  /// tvOS only: overflow as one more circle in the row, because a TV has no toolbar to
  /// put it in. iPhone and Mac hoist the same menu into the navigation toolbar — that
  /// is where a platform's secondary actions belong, and it buys the row a slot back.
  @ViewBuilder
  private var moreButton: some View {
    Menu {
      MediaItemOverflowMenu(isSeries: isSeries,
                            isWatched: isWatched,
                            isBookmarked: isBookmarked,
                            onWatchedToggle: onWatchedToggle,
                            onClearFromContinueWatching: onClearFromContinueWatching,
                            onBrowseWatchlist: onBrowseWatchlist)
    } label: {
      Image(systemName: "ellipsis")
            .font(MediaActionMetrics.labelFont)

//        .font(.system(size: MediaActionMetrics.circleIconPointSize, weight: .bold))
    }
    .mediaActionPillStyle()
    .focused($focus, equals: .more)
    .accessibilityLabel("More")
  }

  /// kino.pub bookmarks are folders — the circle opens the list (plus create).
  @ViewBuilder
  private func folderMenuLabel<Content: View>(@ViewBuilder label: () -> Content) -> some View {
    Menu {
      ForEach(folders, id: \.id) { folder in
        Button {
          onFolderToggle(folder)
        } label: {
          Label {
            Text(folder.title)
          } icon: {
            // Invisible checkmark keeps the column aligned; an empty symbol name
            // here logged "No symbol named ''" per folder per render.
            Image(systemName: "checkmark")
              .opacity(folderIDsContainingItem.contains(folder.id) ? 1 : 0)
          }
        }
      }
      if onCreateFolder != nil {
        if !folders.isEmpty { Divider() }
        Button {
          newFolderName = ""
          showNewFolderAlert = true
        } label: {
          SwiftUI.Label("New Folder", systemImage: "folder.badge.plus")
        }
      }
    } label: {
      label()
    }
    // Folder membership arrives after first paint; rebuild the menu when it flips
    // so `bookmark` → `bookmark.fill` actually reaches the screen.
    .id("\(isBookmarked)-\(folders.count)")
  }

  @ViewBuilder
  private var primaryAction: some View {
    let content = mediaItem.playbackButtonContent
    let target = playTarget
    PlayerLink(route: linkProvider.player(for: target), item: target, mode: .media) {
      primaryActionLabel(for: content)
    }
    .mediaActionPlayPillStyle()
    .focused($focus, equals: .play)
    .accessibilityLabel(Text(playAccessibilityLabel(for: content)))
    .accessibilityHint(Text("Starts playback"))
    // A series episode arrives without its links, and the player fetches them on open —
    // dead time the viewer spends on a spinner. Fetching while the page is on screen moves
    // that request out of the tap. Idempotent and deduplicated, so re-running it is free.
    .task(id: target.id) {
      await PlaybackPreflight.shared.warm(target)
    }
  }

  private func playAccessibilityLabel(for content: PlaybackButtonContent) -> String {
    switch content {
    case .resume(_, let episodeLabel, _):
      if let episodeLabel { return "Resume \(episodeLabel)" }
      return "Resume"
    case .play(let episodeLabel):
      if let episodeLabel { return "Play \(episodeLabel)" }
      return "Play"
    case .playAgain:
      return "Play Again"
    }
  }

  /// Play glyph, optional mini resume bar (only when playback has started), then the title.
  @ViewBuilder
  private func primaryActionLabel(for content: PlaybackButtonContent) -> some View {
    HStack(spacing: MediaActionMetrics.contentSpacing) {
      Image(systemName: "play.fill")
            .font(MediaActionMetrics.labelFont)
//        .font(.system(size: MediaActionMetrics.iconPointSize, weight: .semibold))

      switch content {
      case .resume(let progress, let episodeLabel, let durationSeconds):
        MediaActionProgressTrack(progress: progress)
        Text(Self.resumeMeta(episodeLabel: episodeLabel, durationSeconds: durationSeconds)
          ?? Self.resumeFallback(episodeLabel: episodeLabel))
          .font(MediaActionMetrics.labelFont)
          .lineLimit(1)
      case .play(let episodeLabel):
        if let episodeLabel {
          Text("\("Play".localized) \(episodeLabel)")
            .font(MediaActionMetrics.labelFont)
            .lineLimit(1)
        } else {
          Text("Play")
            .font(MediaActionMetrics.labelFont)
            .lineLimit(1)
        }
      case .playAgain:
        Text("Play Again")
          .font(MediaActionMetrics.labelFont)
          .lineLimit(1)
      }
    }
    // On the label, not the button: the system styles hug their content, and a bare
    // "Play" next to a labelled Trailer would otherwise be the narrower of the two.
    .frame(minWidth: MediaActionMetrics.playPillMinWidth)
  }

  /// For a series, play the first episode that still has something left; the rail
  /// below is there for picking any other one.
  private var playTarget: any PlayableItem {
    guard let (season, episode) = mediaItem.primaryEpisode else { return mediaItem }
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId
    episode.seriesTitle = mediaItem.localizedTitle
    return episode
  }

  /// Meta beside the bar — "S1, E2 · 39 min" or "39 min". Nil means use the Resume word.
  private static func resumeMeta(episodeLabel: String?, durationSeconds: Int) -> String? {
    var parts: [String] = []
    if let episodeLabel { parts.append(episodeLabel) }
    if durationSeconds >= 60 {
      let duration = Duration.compactHoursMinutes(seconds: durationSeconds)
      if !duration.isEmpty { parts.append(duration) }
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private static func resumeFallback(episodeLabel: String?) -> String {
    if let episodeLabel {
      return "\("Resume".localized) \(episodeLabel)"
    }
    return "Resume".localized
  }

  // MARK: - Metrics

  /// Seconds of artwork before the trailer takes over.????? it must start no sooner than this interval after open - but only if the player is ready and asset can play while in hero focus
  static let trailerLeadIn: Double = 2
  /// Non-tvOS only: fade as soon as the hero has scrolled up at all. The old
  /// half-height threshold left the trailer running under the first section below.
  static let onScreenSlop: CGFloat = 150

  /// Leads and directors named in the corner, before the list turns into a paragraph.
  static let creditNameLimit = 3

  /// Genres shown above the names; kino.pub happily returns six.
  static let genreLimit = 3

  /// Co-productions run long — two is enough to say where a title is from.
  static let countryLimit = 2

  /// Everything under the title is one size — real body text, not a caption — and it
  /// is the same size the ratings captions and the information table use further down
  /// the page. See `TypeScale.detailBody`, which is where that decision lives.
  static let secondaryFont: Font = TypeScale.detailBody

  /// Not `text`, not `subtitle`: the row Apple puts under the title looks like primary
  /// text with the artwork faintly coming through it.
  static let metaStyle = Color.KinoPub.text.opacity(0.85)

#if os(tvOS)
  // Unused for layout — the slideshow slide sizes the hero. Kept so shared metrics
  // below stay in one `#if` block.
  static let heroHeight: CGFloat = 1080
  static let horizontalInset: CGFloat = 80
  static let bottomInset: CGFloat = 60
  static let contentSpacing: CGFloat = 12
  static let leadingWidth: CGFloat = 640
  static let logoMaxWidth: CGFloat = 640
  static let logoMaxHeight: CGFloat = 220
  static let titleFont: Font = TypeScale.heroTitle
  static let metaSpacing: CGFloat = 20
  static let actionsGap: CGFloat = 20
  static let actionsRowGap: CGFloat = 16
  static let creditLineSpacing: CGFloat = 4
  static let columnGutter: CGFloat = 48
#elseif os(macOS)
  /// Preview / fallback only — live layout uses `.aspectRatio(16/9)`.
  static let heroHeight: CGFloat = 420
  static let horizontalInset: CGFloat = 32
  static let bottomInset: CGFloat = 28
  static let contentSpacing: CGFloat = 8
  static let leadingWidth: CGFloat = 400
  static let logoMaxWidth: CGFloat = 360
  static let logoMaxHeight: CGFloat = 110
  static let titleFont: Font = TypeScale.heroTitle
  static let metaSpacing: CGFloat = 12
  static let actionsGap: CGFloat = 12
  static let actionsRowGap: CGFloat = 10
  static let creditLineSpacing: CGFloat = 3
  static let columnGutter: CGFloat = 28
#else
  /// Preview / fallback only — live layout uses `.aspectRatio(16/9)`.
  static let heroHeight: CGFloat = 380
  static let horizontalInset: CGFloat = 20
  static let bottomInset: CGFloat = 20
  static let contentSpacing: CGFloat = 8
  static let leadingWidth: CGFloat = 560
  static let logoMaxWidth: CGFloat = 360
  static let logoMaxHeight: CGFloat = 96
  static let titleFont: Font = TypeScale.heroTitle
  static let metaSpacing: CGFloat = 10
  static let actionsGap: CGFloat = 10
  static let actionsRowGap: CGFloat = 10
  static let creditLineSpacing: CGFloat = 3
  static let columnGutter: CGFloat = 16
#endif
}

private extension View {

  /// Was a per-glyph drop shadow; removed 2026-08-09 (real cost, `.shadow` forces an
  /// offscreen pass on every focus/wash animation tick this text rides). Legibility now
  /// has to come from contrast — `bottomScrim` / `titleScrim` under the text — rather
  /// than a shadow chasing the letters. Placeholder kept so call sites don't need
  /// touching again once that contrast pass lands; see
  /// `docs/archive/plans/detail-page-choreography.md`.
  func heroTextShadow() -> some View {
    self
  }
}

#if DEBUG
private struct MediaItemHeroPreview: View {
  @FocusState private var focus: MediaItemFocusTarget?
  @StateObject private var trailer = TrailerPreviewModel()
  @StateObject private var navigationState = NavigationState()
  @State private var heroPhase = MediaItemHeroPhase()

  var body: some View {
    MediaItemHeroView(
      mediaItem: MediaItem.mock(),
      focus: $focus,
      trailer: trailer,
      phase: heroPhase,
      linkProvider: AppRoutesLinkProvider(),
      isWatched: false,
      isBookmarked: true,
      folders: [],
      folderIDsContainingItem: [],
      onWatchedToggle: {},
      onFolderToggle: { _ in },
      titleLogoURL: nil
    )
    .environmentObject(navigationState)
    .aspectRatio(16 / 9, contentMode: .fit)
    .frame(maxWidth: 960)
//    .background(Color.black)
    .preferredColorScheme(.dark)
  }
}

#Preview("Hero + capability badges") {
  MediaItemHeroPreview()
}
#endif
