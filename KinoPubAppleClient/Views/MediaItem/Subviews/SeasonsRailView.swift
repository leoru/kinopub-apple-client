//
//  SeasonsRailView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend

/// Season tabs over one continuous horizontal rail of every episode in the series —
/// S1E1 through the finale — the way the Apple TV app presents a show. Tabs scroll the
/// rail to that season's first episode rather than swapping the content out. Opens
/// scrolled to the first unfinished episode.
///
/// Section chrome (season tabs) stays hidden while the hero owns the page, so the
/// trailer/wide art isn't captioned by "Season 1" peeking under it; it fades in once
/// focus drops onto the rail and the backdrop blurs.
struct SeasonsRailView: View {

  let seasons: [Season]
  let linkProvider: NavigationLinkProvider
  /// Filled into every episode handed to the player, so its transport bar can show the
  /// series name rather than just the episode's own title.
  let seriesTitle: String
  /// False while the hero/trailer is up — season tabs stay out of the way.
  var showsChrome: Bool = true
  var onHide: ((Episode, Season) -> Void)?
  var onToggleWatched: ((Episode, Season) -> Void)?

  @State private var selectedSeasonID: Int?
  @State private var didScrollToUnseen = false
  @FocusState private var focusedEpisodeID: Int?

  private struct Entry: Identifiable {
    var id: Int { episode.id }
    let season: Season
    let episode: Episode
  }

  private var entries: [Entry] {
    seasons.flatMap { season in
      season.episodes.map { Entry(season: season, episode: $0) }
    }
  }

  private var selectedSeason: Season? {
    seasons.first { $0.id == selectedSeasonID } ?? seasons.first
  }

  /// First unfinished episode walking seasons in order, else the very first.
  private var firstUnseen: Entry? {
    entries.first { $0.episode.watched == 0 } ?? entries.first
  }

  var body: some View {
    ScrollViewReader { proxy in
      VStack(alignment: .leading, spacing: showsChrome ? 16 : 0) {
        if showsChrome {
          seasonTabs(proxy: proxy)
            .transition(.opacity)
        }

        episodeRail
      }
      .animation(.easeOut(duration: 0.35), value: showsChrome)
      .onAppear {
        if selectedSeasonID == nil {
          selectedSeasonID = firstUnseen?.season.id ?? seasons.first?.id
        }
      }
      .task {
        await scrollToFirstUnseen(proxy: proxy)
      }
#if os(tvOS)
      .onChange(of: focusedEpisodeID) { _, episodeID in
        guard let episodeID,
              let entry = entries.first(where: { $0.episode.id == episodeID }) else { return }
        selectedSeasonID = entry.season.id
      }
#endif
    }
  }

  // MARK: - Season tabs

  private func seasonTabs(proxy: ScrollViewProxy) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: Self.tabSpacing) {
        ForEach(seasons) { season in
          Button {
            selectedSeasonID = season.id
            withAnimation(.easeOut(duration: 0.25)) {
              proxy.scrollTo(Self.seasonAnchor(season.id), anchor: .leading)
            }
          } label: {
            Text(Self.seasonTitle(season))
              .font(Self.tabFont)
          }
          .buttonStyle(SeasonTabButtonStyle(isSelected: season.id == selectedSeason?.id))
        }
      }
      .padding(.horizontal, Self.horizontalInset)
      .padding(.vertical, Self.focusPadding)
    }
  }

  // MARK: - Episode rail

  private var episodeRail: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
        ForEach(entries) { entry in
          let episode = entry.episode
          let season = entry.season
          let isSeasonStart = season.episodes.first?.id == episode.id

          HStack(spacing: 0) {
            // Zero-width anchor so tabs can scrollTo a season without fighting the
            // episode id used for the first-unseen jump.
            if isSeasonStart {
              Color.clear
                .frame(width: 0, height: 0)
                .id(Self.seasonAnchor(season.id))
            }

            NavigationLink(value: linkProvider.player(for: filled(episode, in: season))) {
              EpisodeRailCard(episode: episode)
            }
            .buttonStyle(EpisodeCardButtonStyle())
#if os(tvOS)
            .focused($focusedEpisodeID, equals: episode.id)
#endif
            .modifier(MediaCardContextMenuModifier(
              actions: contextActions(for: episode, season: season)
            ))
            .id(Self.episodeAnchor(episode.id))
          }
        }
      }
      .padding(.horizontal, Self.horizontalInset)
      .padding(.vertical, Self.focusPadding)
    }
  }

  private func scrollToFirstUnseen(proxy: ScrollViewProxy) async {
    guard !didScrollToUnseen, let target = firstUnseen else { return }
    didScrollToUnseen = true
    selectedSeasonID = target.season.id
    // LazyHStack needs a beat before the destination exists to scroll to.
    try? await Task.sleep(for: .milliseconds(120))
    guard !Task.isCancelled else { return }
    // Scroll only — don't claim focus. The page's defaultFocus stays on Play.
    proxy.scrollTo(Self.episodeAnchor(target.episode.id), anchor: .leading)
  }

  private func contextActions(for episode: Episode, season: Season) -> [MediaCardContextAction] {
    let card = Self.contextCard(for: episode, in: season)
    return MediaCardContextMenus.actions(
      for: card,
      includeGoToTitle: false,
      onHide: { onHide?(episode, season) },
      onToggleWatched: { onToggleWatched?(episode, season) },
      onGoToTitle: {}
    )
  }

  /// Episodes arrive without their season/media context, which playback needs.
  private func filled(_ episode: Episode, in season: Season) -> Episode {
    episode.seasonNumber = season.number
    episode.mediaId = season.mediaId
    episode.seriesTitle = seriesTitle
    return episode
  }

  private static func contextCard(for episode: Episode, in season: Season) -> MediaCard {
    let progress: Double? = {
      guard episode.watched == 0, episode.duration > 0, episode.watching.time > 0 else { return nil }
      return min(Double(episode.watching.time) / Double(episode.duration), 1.0)
    }()
    return MediaCard(id: episode.id,
                     posterURL: episode.thumbnail,
                     title: episode.fixedTitle,
                     progress: progress,
                     landscapeImageURL: episode.thumbnail,
                     itemID: season.mediaId ?? episode.mediaId,
                     video: episode.number,
                     season: season.number,
                     mediaID: episode.id,
                     isWatched: episode.watched > 0,
                     isSeries: true)
  }

  private static func seasonTitle(_ season: Season) -> String {
    if season.title.isEmpty {
      return "\("Season".localized) \(season.number)"
    }
    return season.title
  }

  private static func seasonAnchor(_ id: Int) -> String { "season-\(id)" }
  private static func episodeAnchor(_ id: Int) -> String { "episode-\(id)" }

#if os(tvOS)
  static let horizontalInset: CGFloat = 80
  static let cardSpacing: CGFloat = 36
  static let tabSpacing: CGFloat = 16
  static let focusPadding: CGFloat = 32
  static let tabFont: Font = .system(size: 28, weight: .semibold)
#else
  static let horizontalInset: CGFloat = 20
  static let cardSpacing: CGFloat = 16
  static let tabSpacing: CGFloat = 8
  static let focusPadding: CGFloat = 6
  static let tabFont: Font = .system(size: 16, weight: .semibold)
#endif
}

// MARK: - Episode card

/// Landscape still that keeps its native aspect (no crop), with a permanent
/// "EPISODE 9" label over a up-to-three-line title — always visible, not focus-only.
private struct EpisodeRailCard: View {

  let episode: Episode

  private var episodeNumberLabel: String {
    "\("Episode".localized) \(episode.number)"
  }

  private var episodeTitle: String {
    episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var progress: Double? {
    guard episode.watched == 0, episode.duration > 0, episode.watching.time > 0 else { return nil }
    return min(Double(episode.watching.time) / Double(episode.duration), 1.0)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Self.captionSpacing) {
      still

      VStack(alignment: .leading, spacing: 4) {
        Text(episodeNumberLabel)
          .font(Self.numberFont)
          .foregroundStyle(Color.KinoPub.subtitle)
          .textCase(.uppercase)
          .lineLimit(1)

        if !episodeTitle.isEmpty {
          Text(episodeTitle)
            .font(Self.titleFont)
            .foregroundStyle(Color.KinoPub.text)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(width: Self.cardWidth, alignment: .leading)
    }
    .frame(width: Self.cardWidth, alignment: .leading)
  }

  /// Fixed wide frame, image fitted inside — preserves the still's aspect without
  /// cropping, wider than the old 360pt Continue Watching tile.
  private var still: some View {
    ZStack(alignment: .bottom) {
      Color.KinoPub.placeholder

      AsyncImage(url: URL(string: episode.thumbnail),
                 transaction: Transaction(animation: .easeIn(duration: 0.25))) { phase in
        if let image = phase.image {
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: Self.cardWidth, maxHeight: Self.stillHeight)
            .transition(.opacity)
        }
      }

      if let progress {
        progressBar(progress)
      }
    }
    .frame(width: Self.cardWidth, height: Self.stillHeight)
    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
  }

  private func progressBar(_ progress: Double) -> some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.black.opacity(0.65))
        Capsule()
          .fill(Color.KinoPub.accent)
          .frame(width: geometry.size.width * progress)
      }
    }
    .frame(height: 6)
    .padding(.horizontal, 10)
    .padding(.bottom, 10)
  }

#if os(tvOS)
  static let cardWidth: CGFloat = 480
  static let stillHeight: CGFloat = 270
  static let cornerRadius: CGFloat = 14
  static let captionSpacing: CGFloat = 14
  static let numberFont: Font = .system(size: 18, weight: .semibold)
  static let titleFont: Font = .system(size: 24, weight: .medium)
#else
  static let cardWidth: CGFloat = 300
  static let stillHeight: CGFloat = 169
  static let cornerRadius: CGFloat = 12
  static let captionSpacing: CGFloat = 8
  static let numberFont: Font = .system(size: 11, weight: .semibold)
  static let titleFont: Font = .system(size: 15, weight: .medium)
#endif
}

/// Focus lift for episode cards. Hand-rolled rather than `.borderless`: these cells
/// clip the still to a rounded rect and carry a caption stack, both of which fight
/// the native parallax recipe.
private struct EpisodeCardButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Card(configuration: configuration)
  }

  private struct Card: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .scaleEffect(isFocused ? 1.06 : (configuration.isPressed ? 0.97 : 1.0))
        .shadow(color: .black.opacity(isFocused ? 0.45 : 0), radius: 18, y: 10)
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
  }
}

/// A season tab: filled when selected, outlined otherwise, and lifting on focus.
private struct SeasonTabButtonStyle: ButtonStyle {
  let isSelected: Bool

  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Tab(configuration: configuration, isSelected: isSelected)
  }

  private struct Tab: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
      configuration.label
        .foregroundStyle(isSelected ? Color.black : Color.KinoPub.text)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
          Capsule().fill(isSelected ? Color.KinoPub.accent : Color.KinoPub.selectionBackground)
        )
        .overlay(
          Capsule().stroke(Color.KinoPub.accent, lineWidth: isFocused && !isSelected ? 3 : 0)
        )
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
  }
}
