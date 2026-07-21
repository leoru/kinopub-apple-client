//
//  MediaItemHeroView.swift
//  KinoPubAppleClient
//

import SwiftUI
import AVKit
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

  func start(url: URL?) {
    guard player == nil, let url else { return }

    let player = AVPlayer(url: url)
    player.isMuted = true
    self.player = player

    statusObservation = player.observe(\.currentItem?.status, options: [.new]) { [weak self] player, _ in
      guard player.currentItem?.status == .readyToPlay else { return }
      Task { @MainActor in
        // A failed trailer simply never flips this, leaving the artwork in place.
        self?.isReady = true
        player.play()
      }
    }

    endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                        object: player.currentItem,
                                                        queue: .main) { [weak self] _ in
      Task { @MainActor in
        self?.stop()
      }
    }
  }

  /// Drops back to the artwork — used when the trailer ends or the view goes away.
  func stop() {
    player?.pause()
    isReady = false
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
  }
}

/// Full-bleed artwork that gives way to the trailer, with the title, metadata and
/// actions laid over it — the shape the Apple TV app uses.
struct MediaItemHeroView: View {

  var mediaItem: MediaItem
  var isSkeleton: Bool
  var linkProvider: NavigationLinkProvider
  var onWatchedToggle: () -> Void
  var onBookmarkHandle: () -> Void

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
    .task {
      guard !isSkeleton else { return }
      trailer.start(url: mediaItem.trailerURL)
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

      if let player = trailer.player, trailer.isReady {
        VideoPlayer(player: player)
          .disabled(true)
          .allowsHitTesting(false)
          .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.easeInOut(duration: 0.6), value: trailer.isReady)
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

      ExpandableText(mediaItem.plot,
                     lineLimit: 3,
                     font: Self.plotFont,
                     buttonFont: Self.buttonFont)
        .foregroundStyle(Color.KinoPub.text.opacity(0.85))
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
        Image(systemName: "checkmark")
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)

      Button(action: onBookmarkHandle) {
        Image(systemName: "bookmark")
      }
      .buttonStyle(.bordered)
      .buttonBorderShape(.capsule)
    }
    .font(Self.buttonFont)
    .disabled(isSkeleton)
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
