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

  private func handle(status: AVPlayerItem.Status) {
    switch status {
    case .readyToPlay:
      isReady = true
      player?.play()
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

  @ViewBuilder
  private var backdrop: some View {
    ZStack {
      // Sharp at the top, dissolving toward the text at the bottom.
      ProgressiveBlur(startPoint: 0.35, maxRadius: 44, layers: 5) {
        AsyncImage(url: URL(string: backdropURL)) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        } placeholder: {
          Color.KinoPub.skeleton
        }
      }

      // Left unblurred where the artwork behind it is blurred: a SwiftUI layer effect
      // over an `AVPlayerLayer` does not render, so the extra scrim carries the text
      // instead.
      if let player = trailer.player, trailer.isReady {
        TrailerVideoLayer(player: player)
          .allowsHitTesting(false)
          .transition(.opacity)

        trailerScrim
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.easeInOut(duration: 0.6), value: trailer.isReady)
  }

  /// Extra shade over the trailer only. The artwork arrives softened by the
  /// progressive blur; a sharp, bright, moving frame does not, and white text on a
  /// cartoon sky is unreadable without it.
  private var trailerScrim: some View {
    LinearGradient(stops: [
      .init(color: .clear, location: 0),
      .init(color: Color.KinoPub.background.opacity(0.5), location: 0.6),
      .init(color: Color.KinoPub.background.opacity(0.5), location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

  private var scrim: some View {
    // Reaches the background colour before the very bottom: landing on it only at
    // the last pixel leaves a visible seam where the hero meets the page.
    LinearGradient(stops: [
      .init(color: Color.KinoPub.background.opacity(0.1), location: 0),
      .init(color: Color.KinoPub.background.opacity(0.6), location: 0.5),
      .init(color: Color.KinoPub.background, location: 0.88),
      .init(color: Color.KinoPub.background, location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

  // MARK: - Foreground

  private var content: some View {
    VStack(alignment: .leading, spacing: Self.contentSpacing) {
      Text(mediaItem.localizedTitle)
        .font(Self.titleFont)
        .foregroundStyle(Color.KinoPub.text)
        .lineLimit(2)
        .skeleton(enabled: isSkeleton, size: CGSize(width: 420, height: 44))

      if mediaItem.originalTitle != mediaItem.localizedTitle {
        Text(mediaItem.originalTitle)
          .font(Self.subtitleFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .lineLimit(1)
      }

      metadata

      MediaItemPlotView(title: mediaItem.localizedTitle, plot: mediaItem.plot)
        .frame(maxWidth: Self.textMaxWidth, alignment: .leading)
        .multilineSkeleton(enabled: isSkeleton)

      actions
        .padding(.top, 4)
    }
    .padding(.horizontal, Self.horizontalInset)
    .padding(.bottom, Self.bottomInset)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var metadata: some View {
    HStack(spacing: 12) {
      MediaScoresView(imdb: mediaItem.imdbRating, kinopoisk: mediaItem.kinopoiskRating)

      Text(metadataLine)
        .font(Self.metaFont)
        .foregroundStyle(Color.KinoPub.subtitle)
        .lineLimit(1)
    }
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
    let genres = mediaItem.genres.compactMap(\.title).prefix(2)
    if !genres.isEmpty { parts.append(genres.joined(separator: ", ")) }
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

#if os(tvOS)
  static let heroHeight: CGFloat = 720
  static let horizontalInset: CGFloat = 80
  static let bottomInset: CGFloat = 60
  static let contentSpacing: CGFloat = 12
  static let textMaxWidth: CGFloat = 900
  static let titleFont: Font = .system(size: 62, weight: .bold)
  static let subtitleFont: Font = .system(size: 28, weight: .regular)
  static let metaFont: Font = .system(size: 24, weight: .medium)
  static let plotFont: Font = .system(size: 26, weight: .regular)
  static let buttonFont: Font = .system(size: 26, weight: .semibold)
#elseif os(macOS)
  static let heroHeight: CGFloat = 460
  static let horizontalInset: CGFloat = 32
  static let bottomInset: CGFloat = 28
  static let contentSpacing: CGFloat = 8
  static let textMaxWidth: CGFloat = 620
  static let titleFont: Font = .system(size: 36, weight: .bold)
  static let subtitleFont: Font = .system(size: 18, weight: .regular)
  static let metaFont: Font = .system(size: 14, weight: .medium)
  static let plotFont: Font = .system(size: 15, weight: .regular)
  static let buttonFont: Font = .system(size: 15, weight: .semibold)
#else
  static let heroHeight: CGFloat = 380
  static let horizontalInset: CGFloat = 20
  static let bottomInset: CGFloat = 20
  static let contentSpacing: CGFloat = 8
  static let textMaxWidth: CGFloat = 560
  static let titleFont: Font = .system(size: 28, weight: .bold)
  static let subtitleFont: Font = .system(size: 16, weight: .regular)
  static let metaFont: Font = .system(size: 13, weight: .medium)
  static let plotFont: Font = .system(size: 14, weight: .regular)
  static let buttonFont: Font = .system(size: 14, weight: .semibold)
#endif
}
