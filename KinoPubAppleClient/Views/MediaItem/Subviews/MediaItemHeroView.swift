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
  /// The page's focus target — the primary action claims it, so a page whose content
  /// lands late still opens at the top rather than wherever the focus engine drifted.
  @FocusState.Binding var focus: MediaItemFocusTarget?
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
      guard let url = mediaItem.trailerURL else { return }
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
      ProgressiveBlur(startPoint: 0.5, maxRadius: 44, layers: 5) {
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
      .init(color: .clear, location: 0.4),
      .init(color: Color.KinoPub.background.opacity(0.45), location: 0.75),
      .init(color: Color.KinoPub.background.opacity(0.55), location: 1)
    ], startPoint: .top, endPoint: .bottom)
  }

  private var scrim: some View {
    // Weighted to the bottom third, where the text sits: shading the whole frame
    // evenly turned the artwork into a grey slab. It still lands on the background
    // colour a little before the last pixel, or the hero meets the page on a
    // visible seam.
    LinearGradient(stops: [
      .init(color: .clear, location: 0),
      .init(color: Color.KinoPub.background.opacity(0.15), location: 0.45),
      .init(color: Color.KinoPub.background.opacity(0.7), location: 0.8),
      .init(color: Color.KinoPub.background, location: 0.97),
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
  }

  private var mainColumn: some View {
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

      MediaItemPlotView(title: mediaItem.localizedTitle, plot: mediaItem.plot)

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
    let link = NavigationLink(value: linkProvider.player(for: playTarget)) {
      Label(mediaItem.playbackAction.titleKey.localized, systemImage: "play.fill")
    }
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .tint(Color.KinoPub.accent)

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
  static let heroHeight: CGFloat = 900
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
