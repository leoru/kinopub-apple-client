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
  var gravity: AVLayerVideoGravity = .resizeAspectFill
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

final class TrailerLayerHostView: NSView {

  let playerLayer = AVPlayerLayer()

  init(player: AVPlayer, gravity: AVLayerVideoGravity) {
    super.init(frame: .zero)
    playerLayer.player = player
    playerLayer.videoGravity = gravity
    wantsLayer = true
    layer = CALayer()
    layer?.addSublayer(playerLayer)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    // Without this the layer animates its way to every new size as the window resizes.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    playerLayer.frame = bounds
    CATransaction.commit()
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
/// A blurred `/poster/item/small` wash is always there (cheap, rasterised once).
/// The sharp wide art + trailer sit on top and simply fade to zero when focus
/// leaves the hero — no re-blurring the hero media on the way out.
struct MediaItemHeroBackdrop: View {

  var mediaItem: MediaItem
  @ObservedObject var trailer: TrailerPreviewModel
  var isHeroOnScreen: Bool

  private var wideURL: String {
    mediaItem.posters.wideURL ?? mediaItem.posters.big
  }

  var body: some View {
    ZStack {
      Color.KinoPub.background

      // Always-on page wash. Small poster, tiny buffer, `drawingGroup` — the same
      // trick as `MediaItemView.ambientBackground`, kept live so scroll never has
      // to manufacture a blur from the wide frame.
      blurredPoster

      // Wide + trailer as one layer — fade what the user was looking at, don't
      // peel the trailer off and leave the still underneath mid-scroll.
      heroMedia
        .opacity(isHeroOnScreen ? 1 : 0)

      topGradient
        .opacity(isHeroOnScreen ? 1 : 0)
      bottomScrim
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .ignoresSafeArea()
    .animation(.easeOut(duration: 0.35), value: isHeroOnScreen)
    .animation(.easeInOut(duration: 0.6), value: trailer.isReady)
  }

  /// Scale is derived from the real container so a portrait buffer still covers
  /// a 16:9 screen — a fixed `scaleEffect` of 10 left ~1200pt of width and the
  /// sides fell back to the page colour.
  private var blurredPoster: some View {
    GeometryReader { geo in
      let scale = max(geo.size.width / Self.blurBuffer.width,
                      geo.size.height / Self.blurBuffer.height) * 1.05

      AsyncImage(url: URL(string: mediaItem.posters.small)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: Self.blurBuffer.width, height: Self.blurBuffer.height)
          .clipped()
          .blur(radius: Self.blurRadius, opaque: true)
          .saturation(1.4)
          .drawingGroup()
          .scaleEffect(scale)
          .frame(width: geo.size.width, height: geo.size.height)
          .clipped()
      } placeholder: {
        Color.clear
      }
    }
  }

  @ViewBuilder
  private var heroMedia: some View {
    ZStack {
      AsyncImage(url: URL(string: wideURL),
                 transaction: Transaction(animation: .easeIn(duration: 0.3))) { phase in
        if let image = phase.image {
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .transition(.opacity)
        } else {
          Color.clear
        }
      }

      // Stays in the tree while scrolled away (paused). Gating it on
      // `isHeroOnScreen` used to remove it first, so the fade briefly revealed
      // the wide still under the trailer before the group opacity hit zero.
      if let player = trailer.player, trailer.isReady {
        TrailerVideoLayer(player: player)
          .allowsHitTesting(false)
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Very light black wash from the top edge down to about mid-frame — enough to
  /// settle the status area without dulling the trailer. Fades out with the hero.
  private var topGradient: some View {
    LinearGradient(stops: [
      .init(color: .black.opacity(0.32), location: 0),
      .init(color: .black.opacity(0.12), location: 0.28),
      .init(color: .clear, location: 0.55)
    ], startPoint: .top, endPoint: .bottom)
  }

  /// Soft shade under the title and buttons. A touch stronger once the hero is
  /// gone so section text sits cleanly on the blurred wash.
  private var bottomScrim: some View {
    LinearGradient(stops: [
      .init(color: .clear, location: 0),
      .init(color: .clear, location: 0.5),
      .init(color: .black.opacity(0.2), location: 0.78),
      .init(color: .black.opacity(isHeroOnScreen ? 0.35 : 0.55), location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

  /// Portrait small, rasterised once. Scale is computed at layout time to cover
  /// the screen on both axes.
  private static let blurBuffer = CGSize(width: 120, height: 180)
  private static let blurRadius: CGFloat = 12
}
#endif

/// Full-bleed artwork that gives way to the trailer, with the title, metadata and
/// actions laid over it — the shape the Apple TV app uses.
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
  @Binding var isHeroOnScreen: Bool
  var linkProvider: NavigationLinkProvider
  var isWatched: Bool
  var isBookmarked: Bool
  var folders: [Bookmark]
  var folderIDsContainingItem: Set<Int>
  var onWatchedToggle: () -> Void
  var onFolderToggle: (Bookmark) -> Void

  /// tvOS only: the Up gesture lifts the muted inline preview into a real full-screen
  /// player. Kept here so the same view that owns the preview owns its promotion.
  @State private var isTrailerFullScreen = false

  private var isSeries: Bool {
    !(mediaItem.seasons?.isEmpty ?? true)
  }

  var body: some View {
    // The content drives the height (with a floor) rather than a fixed frame: a fixed
    // one centres anything taller than itself, and `clipped()` then eats the buttons.
    content
      .frame(maxWidth: .infinity, minHeight: Self.heroHeight, alignment: .bottomLeading)
#if !os(tvOS)
      // On tvOS the artwork is pinned behind the whole `ScrollView` at screen height;
      // elsewhere it still scrolls with the hero.
      .background {
        ZStack {
          scrollingBackdrop
          scrollingScrim
        }
      }
      .clipped()
#endif
#if !os(tvOS)
      // tvOS drives the fade from hero focus (see `MediaItemView`); elsewhere the
      // hero scrolls away inside the page and geometry is what we have.
      .background(visibilityProbe)
#endif
#if os(tvOS)
    // The same muted preview, promoted to sound and full screen without restarting.
    // Menu on the remote dismisses it — no chrome of our own over the picture.
    .fullScreenCover(isPresented: $isTrailerFullScreen, onDismiss: { trailer.setFullScreen(false) }) {
      fullScreenTrailer
    }
#endif
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
        .onChange(of: frame.minY >= -Self.onScreenSlop) { onScreen in
          isHeroOnScreen = onScreen
        }
    }
  }

  private var backdropURL: String {
    mediaItem.posters.wideURL ?? mediaItem.posters.big
  }

  @ViewBuilder
  private var scrollingBackdrop: some View {
    ZStack {
      AsyncImage(url: URL(string: backdropURL),
                 transaction: Transaction(animation: .easeIn(duration: 0.3))) { phase in
        if let image = phase.image {
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .transition(.opacity)
        } else {
          Color.KinoPub.placeholder
        }
      }

      if let player = trailer.player, trailer.isReady {
        TrailerVideoLayer(player: player)
          .allowsHitTesting(false)
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

  private var content: some View {
    HStack(alignment: .bottom, spacing: Self.creditsGutter) {
      mainColumn
      Spacer(minLength: 0)
      credits
    }
    .padding(.horizontal, Self.horizontalInset)
    .padding(.bottom, Self.bottomInset)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var mainColumn: some View {
    VStack(alignment: .leading, spacing: Self.contentSpacing) {
      // Shadowed as a block, with the actions left out of it: the buttons carry their
      // own material, and a drop shadow under one that scales on focus is an extra
      // offscreen pass on every frame of the animation.
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

        metadata

        MediaItemPlotView(title: mediaItem.localizedTitle, plot: mediaItem.plot, focus: $focus)
      }
      .heroTextShadow()

      actions
        .padding(.top, Self.actionsGap)
    }
    .frame(maxWidth: Self.textMaxWidth, alignment: .leading)
  }

  /// Year, runtime, country, then the scores. One font and one colour across the
  /// whole line — the scores used to be primary next to a secondary run of text, and
  /// the row read as two different things bolted together.
  private var metadata: some View {
    HStack(spacing: Self.metaSpacing) {
      Text(mediaItem.runtimeLine)
        .lineLimit(1)

      MediaScoresView(imdb: mediaItem.imdbRating, kinopoisk: mediaItem.kinopoiskRating)
    }
    .font(Self.secondaryFont)
    .foregroundStyle(Self.metaStyle)
  }

  /// Genres and names in the far corner of the artwork, the block the Apple TV app
  /// puts there: labels greyed, names picked out, and nothing competing with the
  /// title on the other side.
  @ViewBuilder
  private var credits: some View {
    if !genreLine.isEmpty || !creditLines.isEmpty {
      VStack(alignment: .leading, spacing: 2) {
        if !genreLine.isEmpty {
          Text(genreLine)
            .foregroundStyle(Color.KinoPub.subtitle)
        }

        ForEach(creditLines, id: \.role) { line in
          Text(creditLine(line))
        }
      }
      .font(Self.secondaryFont)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: Self.creditsMaxWidth, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      .heroTextShadow()
    }
  }

  /// One run of attributed text rather than two concatenated `Text`s: the styling
  /// overloads that return `Text` are either iOS 17 or deprecated, and the label has
  /// to flow into the names on the same line anyway.
  private func creditLine(_ line: (role: String, names: String)) -> AttributedString {
    var label = AttributedString(line.role.localized + " ")
    label.foregroundColor = Color.KinoPub.subtitle

    var names = AttributedString(line.names)
    names.foregroundColor = Color.KinoPub.text
    names.font = Self.secondaryFont.weight(.semibold)

    return label + names
  }

  /// Genres carry no label — the words say what they are, and a "Genre:" in front of
  /// them is the kind of form-field caption the Apple TV app never shows.
  private var genreLine: String {
    mediaItem.genres.compactMap(\.title).prefix(Self.genreLimit).joined(separator: ", ")
  }

  /// A handful of leads and whoever directed it — the whole cast is what the section
  /// further down the page is for. A series has no one director to name, so it gets
  /// the cast alone.
  private var creditLines: [(role: String, names: String)] {
    var lines: [(String, String)] = []
    let cast = mediaItem.castMembers.prefix(Self.creditNameLimit)
    if !cast.isEmpty {
      lines.append(("Starring", cast.joined(separator: ", ")))
    }
    if !isSeries {
      let directors = mediaItem.directorNames.prefix(Self.creditNameLimit)
      if !directors.isEmpty {
        lines.append(("Director", directors.joined(separator: ", ")))
      }
    }
    return lines
  }

  private var actions: some View {
    HStack(spacing: 16) {
      primaryAction

      if mediaItem.trailerURL != nil {
        NavigationLink(value: linkProvider.trailerPlayer(for: mediaItem)) {
          Label("Trailer", systemImage: "film")
        }
        .heroButtonStyle()
        .focused($focus, equals: .heroOther)
      }

      // A watched flag is a movie's; a series is marked episode by episode on the rail.
      // Once a movie is watched the control simply goes away rather than inverting into
      // a filled circle — there is nothing left to do to it from here.
      if !isSeries && !isWatched {
        Button(action: onWatchedToggle) {
          Image(systemName: "checkmark")
        }
        .heroButtonStyle()
        .focused($focus, equals: .heroOther)
      }

      bookmarkMenu
    }
    .font(Self.buttonFont)
#if os(tvOS)
    // The focus engine only forwards a move it can't act on, so this fires exactly when
    // a hero button is focused and there is nowhere above to go — the hero is the top of
    // the page. Left/right between the buttons and Down to the rail still navigate as
    // usual; only the dead-end Up is repurposed, and only when a trailer is actually up.
    .onMoveCommand { direction in
      if direction == .up, trailer.player != nil, trailer.isReady {
        isTrailerFullScreen = true
      }
    }
#endif
  }

  /// kino.pub bookmarks are folders, so this offers the list rather than a single
  /// on/off — the icon fills once the item is in at least one of them.
  @ViewBuilder
  private var bookmarkMenu: some View {
    if folders.isEmpty {
      Button {
        // Nothing to add to until the account has a folder.
      } label: {
        Image(systemName: "bookmark")
      }
      .heroButtonStyle()
      .focused($focus, equals: .heroOther)
      .disabled(true)
    } else {
      Menu {
        ForEach(folders, id: \.id) { folder in
          Button {
            onFolderToggle(folder)
          } label: {
            Label(folder.title,
                  systemImage: folderIDsContainingItem.contains(folder.id) ? "checkmark" : "")
          }
        }
      } label: {
        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
      }
      .heroButtonStyle()
      .focused($focus, equals: .heroOther)
      // The folder ids arrive after the first render, and a `Menu` renders its label
      // once and holds onto it — the ternary above was already right, but the flip from
      // `bookmark` to `bookmark.fill` never reached the screen because the label was
      // never asked to redraw. Keying the menu on the state it depends on rebuilds it
      // the moment the item turns out to be filed somewhere.
      .id(isBookmarked)
    }
  }

  @ViewBuilder
  private var primaryAction: some View {
    // Black at rest like the rest of the row, but it keeps its title label while the
    // others are glyph-only, and it holds default focus — so it still reads as the one
    // thing to press without a coloured fill setting it apart.
    let link = NavigationLink(value: linkProvider.player(for: playTarget)) {
      Label(mediaItem.playbackAction.titleKey.localized, systemImage: "play.fill")
    }
      .heroButtonStyle()

    link.focused($focus, equals: .play)
  }

  /// For a series, play the first episode that still has something left; the rail
  /// below is there for picking any other one.
  private var playTarget: any PlayableItem {
    guard isSeries, let seasons = mediaItem.seasons else { return mediaItem }
    for season in seasons {
      if let episode = season.episodes.first(where: { $0.watched == 0 }) {
        episode.seasonNumber = season.number
        episode.mediaId = season.mediaId
        episode.seriesTitle = mediaItem.localizedTitle
        return episode
      }
    }
    if let season = seasons.first, let episode = season.episodes.first {
      episode.seasonNumber = season.number
      episode.mediaId = season.mediaId
      episode.seriesTitle = mediaItem.localizedTitle
      return episode
    }
    return mediaItem
  }

  // MARK: - Metrics

  /// Seconds of artwork before the trailer takes over.
  static let trailerLeadIn: Double = 2
  /// Non-tvOS only: fade as soon as the hero has scrolled up at all. The old
  /// half-height threshold left the trailer running under the first section below.
  static let onScreenSlop: CGFloat = 8

  /// Leads and directors named in the corner, before the list turns into a paragraph.
  static let creditNameLimit = 3

  /// Genres shown beside the names; kino.pub happily returns six.
  static let genreLimit = 3

  /// Everything under the title is one size, taken from the system scale rather than
  /// picked by hand — a bespoke 24/26/28 next to real tvOS controls reads as foreign.
  /// 29 pt on tvOS.
  static let secondaryFont: Font = .subheadline

  /// Not `text`, not `subtitle`: the row Apple puts under the title looks like primary
  /// text with the artwork faintly coming through it.
  static let metaStyle = Color.KinoPub.text.opacity(0.85)

#if os(tvOS)
  // The artwork itself is pinned full-bleed behind the ScrollView (see
  // `MediaItemHeroBackdrop`). This height is only the hero *content* — title,
  // metadata, buttons — so a strip of the next section still peeks under the
  // actions and says the page scrolls. 980 + the 44pt section gap leaves ~56pt
  // of seasons/ratings on a 1080 screen.
  static let heroHeight: CGFloat = 980
  static let horizontalInset: CGFloat = 80
  static let bottomInset: CGFloat = 60
  static let contentSpacing: CGFloat = 12
  static let textMaxWidth: CGFloat = 900
  static let titleFont: Font = .system(size: 62, weight: .bold)
  static let buttonFont: Font = .system(size: 26, weight: .semibold)
  static let metaSpacing: CGFloat = 20
  static let actionsGap: CGFloat = 20
  static let creditsMaxWidth: CGFloat = 520
  static let creditsGutter: CGFloat = 60
#elseif os(macOS)
  static let heroHeight: CGFloat = 460
  static let horizontalInset: CGFloat = 32
  static let bottomInset: CGFloat = 28
  static let contentSpacing: CGFloat = 8
  static let textMaxWidth: CGFloat = 620
  static let titleFont: Font = .system(size: 36, weight: .bold)
  static let buttonFont: Font = .system(size: 15, weight: .semibold)
  static let metaSpacing: CGFloat = 12
  static let actionsGap: CGFloat = 12
  static let creditsMaxWidth: CGFloat = 300
  static let creditsGutter: CGFloat = 28
#else
  static let heroHeight: CGFloat = 380
  static let horizontalInset: CGFloat = 20
  static let bottomInset: CGFloat = 20
  static let contentSpacing: CGFloat = 8
  static let textMaxWidth: CGFloat = 560
  static let titleFont: Font = .system(size: 28, weight: .bold)
  static let buttonFont: Font = .system(size: 14, weight: .semibold)
  static let metaSpacing: CGFloat = 10
  static let actionsGap: CGFloat = 10
  static let creditsMaxWidth: CGFloat = 240
  static let creditsGutter: CGFloat = 16
#endif
}

private extension View {

  /// Legibility that costs the picture nothing: the shade sits where the letters are
  /// instead of over the whole frame, so the trailer stays readable behind the text.
  func heroTextShadow() -> some View {
    shadow(color: .black.opacity(0.8), radius: 22, y: 6)
  }

  /// The one look every hero action wears: a solid black capsule at rest, the way the
  /// user asked — no accent-green primary among them. Black is the *prominent* fill
  /// rather than a `.bordered` tint so the button is a solid shape and not a faint
  /// wash, and because it is the system prominent style tvOS still does its own thing
  /// on focus — lifting the control and turning it bright — so a focused button is
  /// unmistakable at ten feet even though its resting colour is black.
  func heroButtonStyle() -> some View {
    buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .tint(.black)
  }
}
