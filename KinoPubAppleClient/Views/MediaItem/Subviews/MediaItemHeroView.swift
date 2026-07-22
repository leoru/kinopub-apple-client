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

  /// Pauses rather than tears down when the hero scrolls away: the trailer keeps its
  /// place, and it is stopping the decode that gives the GPU back — an `AVPlayerLayer`
  /// still decoding behind the seasons rail is what made focus there stutter.
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
}

#if os(macOS)
extension TrailerVideoLayer: NSViewRepresentable {
  func makeNSView(context: Context) -> TrailerLayerHostView {
    TrailerLayerHostView(player: player)
  }

  func updateNSView(_ view: TrailerLayerHostView, context: Context) {
    view.playerLayer.player = player
  }
}

final class TrailerLayerHostView: NSView {

  let playerLayer = AVPlayerLayer()

  init(player: AVPlayer) {
    super.init(frame: .zero)
    playerLayer.player = player
    playerLayer.videoGravity = .resizeAspectFill
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
    TrailerLayerHostView(player: player)
  }

  func updateUIView(_ view: TrailerLayerHostView, context: Context) {
    view.playerLayer.player = player
  }
}

final class TrailerLayerHostView: UIView {

  override class var layerClass: AnyClass { AVPlayerLayer.self }

  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

  init(player: AVPlayer) {
    super.init(frame: .zero)
    playerLayer.player = player
    playerLayer.videoGravity = .resizeAspectFill
    isUserInteractionEnabled = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
#endif

/// Default focus is stated with the tvOS-only focus-scope pair; everywhere else these
/// are no-ops so the hero stays one view.
private extension View {

  @ViewBuilder
  func heroFocusScope(_ namespace: Namespace.ID) -> some View {
#if os(tvOS)
    focusScope(namespace)
#else
    self
#endif
  }

  @ViewBuilder
  func prefersHeroDefaultFocus(_ namespace: Namespace.ID) -> some View {
#if os(tvOS)
    prefersDefaultFocus(true, in: namespace)
#else
    self
#endif
  }

  /// Legibility that costs the picture nothing: the shade sits where the letters are
  /// instead of over the whole frame, so the trailer stays readable behind the text.
  func heroTextShadow() -> some View {
    shadow(color: .black.opacity(0.8), radius: 22, y: 6)
  }
}

/// Full-bleed artwork that gives way to the trailer, with the title, metadata and
/// actions laid over it — the shape the Apple TV app uses.
struct MediaItemHeroView: View {

  var mediaItem: MediaItem
  var isSkeleton: Bool
  var linkProvider: NavigationLinkProvider
  var isWatched: Bool
  var isBookmarked: Bool
  var folders: [Bookmark]
  var folderIDsContainingItem: Set<Int>
  var onWatchedToggle: () -> Void
  var onFolderToggle: (Bookmark) -> Void

  @StateObject private var trailer = TrailerPreviewModel()
  /// Play is where the remote should land — without a stated preference tvOS focuses
  /// the first control in the layout, which is the synopsis.
  @Namespace private var heroFocus
  @State private var isOnScreen = true

  private var backdropURL: String {
    mediaItem.posters.wideURL ?? mediaItem.posters.big
  }

  private var isSeries: Bool {
    !(mediaItem.seasons?.isEmpty ?? true)
  }

  var body: some View {
    // The content drives the height (with a floor) rather than a fixed frame: a fixed
    // one centres anything taller than itself, and `clipped()` then eats the buttons.
    content
      .frame(maxWidth: .infinity, minHeight: Self.heroHeight, alignment: .bottomLeading)
      .background {
        ZStack {
          backdrop
          scrim
        }
      }
      .clipped()
      .background(visibilityProbe)
      .onChange(of: isOnScreen) { onScreen in
        trailer.setActive(onScreen)
      }
    // Keyed on the URL, not on appearance: the details arrive after the first render,
    // so at `onAppear` there is no trailer to start yet and a plain `.task` never
    // looked again.
    .task(id: mediaItem.trailerURL) {
      guard !isSkeleton, let url = mediaItem.trailerURL else { return }
      // The artwork holds the frame for a beat before the trailer takes over, the way
      // the Apple TV app does it — and a quick scroll past doesn't spin up a video.
      try? await Task.sleep(for: .seconds(Self.trailerLeadIn))
      guard !Task.isCancelled else { return }
      trailer.start(url: url)
    }
    .onDisappear {
      trailer.stop()
    }
  }

  // MARK: - Background

  /// The hero sits in a plain `VStack` inside the page's `ScrollView`, so it is never
  /// removed from the hierarchy and `onDisappear` only fires when the whole page goes
  /// away — not when the hero scrolls off the top. Its frame in the scroll view's own
  /// space is what actually says whether it is on screen.
  private var visibilityProbe: some View {
    GeometryReader { proxy in
      let frame = proxy.frame(in: .named(MediaItemLayout.scrollSpace))
      Color.clear
        .onChange(of: frame.maxY > proxy.size.height * Self.onScreenFraction) { onScreen in
          isOnScreen = onScreen
        }
    }
  }

  @ViewBuilder
  private var backdrop: some View {
    ZStack {
      AsyncImage(url: URL(string: backdropURL)) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Color.KinoPub.skeleton
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
  /// seam. What carries the text is `textShadow` on the type itself, not a slab over
  /// the picture.
  private var scrim: some View {
    LinearGradient(stops: [
      .init(color: .clear, location: 0),
      .init(color: .clear, location: 0.62),
      .init(color: Color.KinoPub.background.opacity(0.32), location: 0.82),
      .init(color: Color.KinoPub.background.opacity(0.9), location: 0.97),
      .init(color: Color.KinoPub.background, location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

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
    .heroFocusScope(heroFocus)
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
          .skeleton(enabled: isSkeleton, size: CGSize(width: 420, height: 44))

        metadata

        MediaItemPlotView(title: mediaItem.localizedTitle, plot: mediaItem.plot)
          .multilineSkeleton(enabled: isSkeleton)
      }
      .heroTextShadow()

      actions
        .padding(.top, Self.actionsGap)
    }
    .frame(maxWidth: Self.textMaxWidth, alignment: .leading)
  }

  /// Names in the far corner of the artwork, the block the Apple TV app puts there:
  /// the label greyed, the names picked out, and nothing else competing with the
  /// title on the other side.
  @ViewBuilder
  private var credits: some View {
    if !isSkeleton, !genreLine.isEmpty || !creditLines.isEmpty {
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

  /// A handful of leads and whoever directed it — the whole cast is what the section
  /// further down the page is for. A series has no one director to name, so it gets
  /// the cast alone.
  /// Genres carry no label — the words say what they are, and a "Genre:" in front of
  /// them is the kind of form-field caption the Apple TV app never shows.
  private var genreLine: String {
    mediaItem.genres.compactMap(\.title).prefix(Self.genreLimit).joined(separator: ", ")
  }

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

  /// Year, runtime, country, then the scores. One font and one colour across the
  /// whole line — the scores used to be primary next to a secondary run of text, and
  /// the row read as two different things bolted together.
  private var metadata: some View {
    HStack(spacing: Self.metaSpacing) {
      Text(metadataLine)
        .lineLimit(1)

      MediaScoresView(imdb: mediaItem.imdbRating, kinopoisk: mediaItem.kinopoiskRating)
    }
    .font(Self.secondaryFont)
    .foregroundStyle(Self.metaStyle)
    .skeleton(enabled: isSkeleton, size: CGSize(width: 320, height: 24))
  }

  private var metadataLine: String {
    var parts: [String] = []
    if mediaItem.year > 0 { parts.append("\(mediaItem.year)") }
    if isSeries, let seasons = mediaItem.seasons {
      // `duration.total` sums every episode, which reads as a nonsense runtime for a
      // series — season count is what the Apple TV app shows.
      parts.append("\(seasons.count) \(seasons.count == 1 ? "season" : "seasons")")
    } else {
      let duration = mediaItem.duration.hoursMinutesFormatted
      if !duration.isEmpty { parts.append(duration) }
    }
    if let country = mediaItem.countries.first?.title { parts.append(country) }
    return parts.joined(separator: " · ")
  }

  private var actions: some View {
    HStack(spacing: 16) {
      primaryAction

      if mediaItem.trailerURL != nil {
        NavigationLink(value: linkProvider.trailerPlayer(for: mediaItem)) {
          Label("Trailer", systemImage: "film")
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
      }

      Button(action: onWatchedToggle) {
        Image(systemName: isWatched ? "checkmark.circle.fill" : "checkmark")
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)

      bookmarkMenu
    }
    .font(Self.buttonFont)
    .disabled(isSkeleton)
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
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)
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
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)
    }
  }

  @ViewBuilder
  private var primaryAction: some View {
    NavigationLink(value: linkProvider.player(for: playTarget)) {
      Label(mediaItem.playbackAction.titleKey.localized, systemImage: "play.fill")
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .tint(Color.KinoPub.accent)
    .prefersHeroDefaultFocus(heroFocus)
  }

  /// For a series, play the first episode that still has something left; the rail
  /// below is there for picking any other one.
  private var playTarget: any PlayableItem {
    guard isSeries, let seasons = mediaItem.seasons else { return mediaItem }
    for season in seasons {
      if let episode = season.episodes.first(where: { $0.watched == 0 }) {
        episode.seasonNumber = season.number
        episode.mediaId = season.mediaId
        return episode
      }
    }
    if let season = seasons.first, let episode = season.episodes.first {
      episode.seasonNumber = season.number
      episode.mediaId = season.mediaId
      return episode
    }
    return mediaItem
  }

  // MARK: - Metrics

  /// Seconds of artwork before the trailer takes over.
  static let trailerLeadIn: Double = 2
  /// How much of the hero has to remain on screen for the trailer to keep playing. On
  /// tvOS scrolling *is* focus movement, so this pauses as focus reaches the seasons
  /// rail — which is where the stutter was.
  static let onScreenFraction: CGFloat = 0.5

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
  // tvOS lays out in a fixed 1920×1080, so this is 83% of the screen — the artwork
  // owns the page the way it does on Apple TV, and stops short of a full 16:9 so the
  // sections underneath still peek in and say there is more to scroll to.
  /// Nothing here is pinned to 16:9 — the artwork is `.fill`, so it crops to whatever
  /// this says. Set against the 1080pt screen: 980 here plus the 44pt section gap
  /// leaves a ~56pt strip of the seasons rail showing, enough to say the page scrolls
  /// without turning the hero into a wide letterbox. Raise it to shrink that strip.
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
